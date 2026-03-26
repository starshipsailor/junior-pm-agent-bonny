#!/bin/bash
# =============================================================================
# Bonny Orchestrator — Processes inbox items and takes action
# =============================================================================
# Runs every hour via launchd. Reads all per-monitor inboxes, processes
# pending items per operating_guidelines.md, executes actions via skill files,
# and performs health checks on monitors.
#
# Usage:
#   ./scripts/bonny-run.sh              # Normal scheduled run
#   ./scripts/bonny-run.sh --dry-run    # Show config and exit without running
# =============================================================================

set -euo pipefail

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/config/bonny.json"
STATE_DIR="$PROJECT_ROOT/state"
LOG_DIR="$PROJECT_ROOT/logs"
LOCKFILE="$STATE_DIR/bonny.lock"
SPEND_FILE="$STATE_DIR/daily-spend.json"
SECRETS_FILE="$PROJECT_ROOT/config/secrets.env"

# --- Ensure directories exist ---
mkdir -p "$STATE_DIR" "$LOG_DIR" "$STATE_DIR/slack-drafts" "$STATE_DIR/confluence-drafts"

# --- Source secrets ---
if [ -f "$SECRETS_FILE" ]; then
  set -a
  source "$SECRETS_FILE"
  set +a
fi

# --- Lock file (prevent concurrent runs) ---
if [ -f "$LOCKFILE" ]; then
  PID=$(cat "$LOCKFILE")
  if kill -0 "$PID" 2>/dev/null; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Another Bonny run is active (PID $PID). Skipping."
    exit 0
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Stale lock file found (PID $PID no longer running). Removing."
    rm -f "$LOCKFILE"
  fi
fi
echo $$ > "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT

# --- Check prerequisites ---
if ! command -v claude &> /dev/null; then
  echo "ERROR: Claude Code CLI not found in PATH." >&2
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo "ERROR: jq is required. Install with: brew install jq" >&2
  exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: Config file not found at $CONFIG_FILE" >&2
  exit 1
fi

# --- Read configuration ---
MAX_BUDGET=$(jq -r '.max_budget_usd // "5.00"' "$CONFIG_FILE")
MODEL=$(jq -r '.model // "sonnet"' "$CONFIG_FILE")

# --- Budget gate ---
if [ -f "$SPEND_FILE" ]; then
  CURRENT_DATE=$(date '+%Y-%m-%d')
  SPEND_DATE=$(jq -r '.date // ""' "$SPEND_FILE" 2>/dev/null || echo "")
  if [ "$SPEND_DATE" = "$CURRENT_DATE" ]; then
    BUDGET_CAP=$(jq -r '.daily_budget_cap_usd // 50' "$CONFIG_FILE" 2>/dev/null || echo "50")
    # Check for temporary daily override
    OVERRIDE_FILE="$STATE_DIR/budget-override.json"
    if [ -f "$OVERRIDE_FILE" ]; then
      OVERRIDE_DATE=$(jq -r '.date // ""' "$OVERRIDE_FILE" 2>/dev/null || echo "")
      if [ "$OVERRIDE_DATE" = "$CURRENT_DATE" ]; then
        BUDGET_CAP=$(jq -r '.cap // '"$BUDGET_CAP"'' "$OVERRIDE_FILE" 2>/dev/null || echo "$BUDGET_CAP")
      fi
    fi
    TOTAL=$(jq -r '.total_usd // 0' "$SPEND_FILE" 2>/dev/null || echo "0")
    if [ "$(echo "$TOTAL >= $BUDGET_CAP" | bc -l 2>/dev/null || echo 0)" = "1" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Daily budget cap reached (\$$TOTAL / \$$BUDGET_CAP). Skipping."
      exit 0
    fi
  else
    echo "{\"date\": \"$CURRENT_DATE\", \"runs\": [], \"total_usd\": 0}" > "$SPEND_FILE"
  fi
fi

# --- Dry run mode ---
if [ "${1:-}" = "--dry-run" ]; then
  echo "=== Bonny Orchestrator Dry Run ==="
  echo "Project root:  $PROJECT_ROOT"
  echo "Model:         $MODEL"
  echo "Budget:        \$$MAX_BUDGET"
  echo ""
  echo "Inbox files:"
  for f in "$PROJECT_ROOT"/Mission_Control/inbox-*.md; do
    PENDING=$(grep -c "Status: pending" "$f" 2>/dev/null || echo "0")
    echo "  $(basename "$f"): $PENDING pending items"
  done
  echo ""
  echo "Monitor health:"
  for m in slack confluence meeting; do
    WM="$STATE_DIR/${m}-monitor-last-run.json"
    if [ -f "$WM" ]; then
      STATUS=$(jq -r '.status // "unknown"' "$WM")
      LAST=$(jq -r '.last_success // "never"' "$WM")
      echo "  ${m}-monitor: status=$STATUS, last_success=$LAST"
    else
      echo "  ${m}-monitor: no watermark file"
    fi
  done
  echo ""
  echo "Would invoke Claude Code with the above config. Exiting."
  exit 0
fi

# --- Build prompt ---
NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

PROMPT="You are the Bonny Orchestrator. Your job is to process pending inbox items and take appropriate actions.

Current date: $(date '+%Y-%m-%d')
Current time: $(date '+%H:%M')

## Phase 1: Load Context
1. Read state/context-digest.md for pre-compiled vault context
   - If it doesn't exist, read: operating_guidelines.md, Business_Chapter/chapter_strategy.md, People/Global_people_index.md
2. Read operating_guidelines.md for the decision framework and routing rules
3. Read Outputs_and_Self_Improvement/questions_for_rohan.md for any existing open questions

## Phase 2: Read All Inboxes
4. Read Mission_Control/inbox-slack.md — identify items with Status: pending
5. Read Mission_Control/inbox-confluence.md — identify items with Status: pending
6. Read Mission_Control/inbox-meetings.md — identify items with Status: pending
7. If there are no pending items across all inboxes, log that and exit early.

## Phase 3: Process Each Item
Sort all pending items by priority:
  BLOCKER > ACTION_ITEM (Rohan named) > ACTION_ITEM (others) > DECISION > STATUS_CHANGE > PERSONNEL > RISK

For each pending item, in priority order:
  a. Read the related project/team files from the vault for full context
  b. Check if the information is already captured in the vault (deduplication)
  c. Apply the routing rules from operating_guidelines.md to determine the action
  d. Execute the action by reading the relevant skill file first:
     - Update vault: Read .claude/commands/skills/update-vault.md, then edit the file
     - Draft Slack: Read .claude/commands/skills/draft-slack.md, then write draft to state/slack-drafts/
     - Write Confluence: Read .claude/commands/skills/write-confluence.md, then draft content
     - Update tasks: Read .claude/commands/skills/update-tasks.md, then append
     - Do nothing: Log reasoning to Outputs_and_Self_Improvement/questions_for_rohan.md
  e. Mark the item's Status as processed (or duplicate) in the inbox file
  f. Log the action to Outputs_and_Self_Improvement/action_log.md with a unique task ID

## Phase 4: Health Check
8. Check state/slack-monitor-last-run.json — flag if last_success is more than 60 minutes ago or status is error
9. Check state/confluence-monitor-last-run.json — flag if last_success is more than 4 hours ago or status is error
10. Check state/meeting-monitor-last-run.json — flag if last_success is more than 2 hours ago or status is error
11. If any monitor is unhealthy, note it in the summary and log to questions_for_rohan.md

## Phase 5: Summary
12. Print a summary: total items processed, actions taken (vault updates, drafts written, questions logged), items skipped as duplicates
13. Log the run to Mission_Control/agent_activity_log.md"

# --- Run Claude Code ---
LOG_FILE="$LOG_DIR/$(date '+%Y-%m-%d_%H%M%S').log"

echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting Bonny orchestrator run..."
echo "  Model: $MODEL"
echo "  Budget: \$$MAX_BUDGET"
echo "  Log: $LOG_FILE"

cd "$PROJECT_ROOT"

claude \
  --print \
  --model "$MODEL" \
  --max-budget-usd "$MAX_BUDGET" \
  --permission-mode bypassPermissions \
  --mcp-config "$PROJECT_ROOT/.mcp.json" \
  --output-format text \
  -p "$PROMPT" \
  2>&1 | tee "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}

echo "" >> "$LOG_FILE"
echo "Exit code: $EXIT_CODE" >> "$LOG_FILE"

# --- Update daily spend ---
if [ -f "$SPEND_FILE" ]; then
  CURRENT_DATE=$(date '+%Y-%m-%d')
  jq --arg m "orchestrator" --arg ts "$NOW" --arg b "$MAX_BUDGET" --arg d "$CURRENT_DATE" \
    'if .date == $d then
       .runs += [{"monitor": $m, "timestamp": $ts, "max_budget": ($b | tonumber)}]
       | .total_usd += ($b | tonumber)
     else
       {"date": $d, "runs": [{"monitor": $m, "timestamp": $ts, "max_budget": ($b | tonumber)}], "total_usd": ($b | tonumber)}
     end' "$SPEND_FILE" > "${SPEND_FILE}.tmp" \
    && mv "${SPEND_FILE}.tmp" "$SPEND_FILE" \
    || true
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Bonny orchestrator completed (exit code: $EXIT_CODE)"

if [ $EXIT_CODE -ne 0 ]; then
  echo "WARNING: Claude Code exited with non-zero status." >&2
fi

exit $EXIT_CODE
