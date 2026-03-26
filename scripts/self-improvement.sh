#!/bin/bash
# =============================================================================
# Bonny Self-Improvement Loop — Reviews actions and learns from corrections
# =============================================================================
# Runs daily at 7am via launchd. Diffs Bonny's Slack drafts vs what Rohan
# actually sent, identifies patterns, and proposes updates to skills/guidelines.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_DIR="$PROJECT_ROOT/state"
LOG_DIR="$PROJECT_ROOT/logs"
LOCKFILE="$STATE_DIR/self-improvement.lock"
SPEND_FILE="$STATE_DIR/daily-spend.json"
CONFIG_FILE="$PROJECT_ROOT/config/bonny.json"
SECRETS_FILE="$PROJECT_ROOT/config/secrets.env"
MONITOR_NAME="self-improvement"
MAX_BUDGET="3.00"

mkdir -p "$STATE_DIR" "$LOG_DIR"

# --- Source secrets ---
if [ -f "$SECRETS_FILE" ]; then
  set -a
  source "$SECRETS_FILE"
  set +a
fi

# --- Lock file ---
if [ -f "$LOCKFILE" ]; then
  PID=$(cat "$LOCKFILE")
  if kill -0 "$PID" 2>/dev/null; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Self-improvement already running (PID $PID). Skipping."
    exit 0
  fi
  rm -f "$LOCKFILE"
fi
echo $$ > "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT

# --- Check prerequisites ---
if ! command -v claude &> /dev/null; then
  echo "ERROR: Claude Code CLI not found." >&2
  exit 1
fi

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

NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# --- Build prompt ---
PROMPT="You are the Bonny Self-Improvement agent. Review yesterday's actions and learn from them.

Current date: $(date '+%Y-%m-%d')

## Step 1: Read Action Log
Read Outputs_and_Self_Improvement/action_log.md for entries from the last 24 hours.
If there are no entries, log that and exit early.

## Step 2: Review Slack Drafts
For each slack-draft action in the log:
  a. Read the draft file from state/slack-drafts/ (using the task_id from the log)
  b. Check if the draft's status is still pending-review or has been sent
  c. Search Slack (via the Slack plugin) for messages sent by Rohan to the same recipient/channel around the same time
  d. If Rohan sent a message on the same topic:
     - Compare Bonny's draft vs what Rohan actually sent
     - Note differences: tone, length, content, phrasing
     - Identify patterns (e.g., 'Bonny's drafts are too formal', 'Bonny misses context about X')

## Step 3: Review Vault Updates
For each vault-update action in the log:
  a. Read the file that was updated
  b. Verify the update is still accurate and well-formatted
  c. Note any issues (broken wikilinks, incorrect data, formatting problems)

## Step 4: Check Stale Questions
Read Outputs_and_Self_Improvement/questions_for_rohan.md.
For any questions older than 3 days that are still unanswered:
  - Draft a gentle Slack DM reminder to Rohan using the draft-slack skill
  - Save to state/slack-drafts/ with status pending-review

## Step 5: Write Review
Write findings to Outputs_and_Self_Improvement/self_improvement_reviews/$(date '+%Y-%m-%d')-review.md:

---
type: self-improvement-review
date: $(date '+%Y-%m-%d')
actions_reviewed: [count]
drafts_compared: [count]
patterns_found: [count]
---

### Draft Comparison Results
[For each draft that was compared to actual sent message]

### Patterns Identified
[Recurring themes across multiple actions]

### Proposed Skill/Guideline Updates
[Specific, actionable suggestions for improving skills or operating guidelines]

## Step 6: Log Activity
Append to Mission_Control/agent_activity_log.md:
| YYYY-MM-DD HH:MM | self-improvement | Reviewed N actions, compared M drafts, found K patterns | budget: \$X.XX |"

# --- Run Claude Code ---
LOG_FILE="$LOG_DIR/${MONITOR_NAME}-$(date '+%Y-%m-%d_%H%M%S').log"

echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting self-improvement review..."

cd "$PROJECT_ROOT"

claude \
  --print \
  --model sonnet \
  --max-budget-usd "$MAX_BUDGET" \
  --permission-mode bypassPermissions \
  --mcp-config "$PROJECT_ROOT/.mcp.json" \
  --output-format text \
  -p "$PROMPT" \
  2>&1 | tee "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}

# --- Update daily spend ---
if [ -f "$SPEND_FILE" ]; then
  CURRENT_DATE=$(date '+%Y-%m-%d')
  jq --arg m "$MONITOR_NAME" --arg ts "$NOW" --arg b "$MAX_BUDGET" --arg d "$CURRENT_DATE" \
    'if .date == $d then
       .runs += [{"monitor": $m, "timestamp": $ts, "max_budget": ($b | tonumber)}]
       | .total_usd += ($b | tonumber)
     else
       {"date": $d, "runs": [{"monitor": $m, "timestamp": $ts, "max_budget": ($b | tonumber)}], "total_usd": ($b | tonumber)}
     end' "$SPEND_FILE" > "${SPEND_FILE}.tmp" \
    && mv "${SPEND_FILE}.tmp" "$SPEND_FILE" \
    || true
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Self-improvement review completed (exit code: $EXIT_CODE)."
