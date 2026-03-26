#!/bin/bash
# =============================================================================
# Bonny Confluence Monitor — Thin runner that invokes the Confluence monitor skill
# =============================================================================
# Runs every 2 hours via launchd. Reads watermark, checks budget, invokes
# Claude Code with the skill file, then updates watermark and spend tracking.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_DIR="$PROJECT_ROOT/state"
LOG_DIR="$PROJECT_ROOT/logs"
LOCKFILE="$STATE_DIR/confluence-monitor.lock"
WATERMARK_FILE="$STATE_DIR/confluence-monitor-last-run.json"
SPEND_FILE="$STATE_DIR/daily-spend.json"
CONFIG_FILE="$PROJECT_ROOT/config/bonny.json"
SECRETS_FILE="$PROJECT_ROOT/config/secrets.env"
MONITOR_NAME="confluence-monitor"
MAX_BUDGET="2.00"

mkdir -p "$STATE_DIR" "$LOG_DIR"

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
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Confluence monitor already running (PID $PID). Skipping."
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

# --- Read watermark ---
FROM_TIMESTAMP="null"
if [ -f "$WATERMARK_FILE" ]; then
  FROM_TIMESTAMP=$(jq -r '.last_success // "null"' "$WATERMARK_FILE" 2>/dev/null || echo "null")
fi

NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# --- Build prompt ---
PROMPT="You are the Bonny Confluence Monitor agent.

Read and execute the skill file at .claude/commands/skills/confluence-monitor-skill.md

Time window: FROM_TIMESTAMP=$FROM_TIMESTAMP to NOW=$NOW
If FROM_TIMESTAMP is null, check pages modified in the last 2 hours.

Current time: $(date '+%Y-%m-%d %H:%M')

Execute all steps in the skill file. Write actionable items to Mission_Control/inbox-confluence.md."

# --- Run Claude Code ---
LOG_FILE="$LOG_DIR/${MONITOR_NAME}-$(date '+%Y-%m-%d_%H%M%S').log"

echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting Confluence monitor..."

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

# --- Update watermark ---
if [ $EXIT_CODE -eq 0 ]; then
  cat > "$WATERMARK_FILE" <<EOF
{
  "last_success": "$NOW",
  "items_found": 0,
  "items_written": 0,
  "status": "ok",
  "error": null
}
EOF
else
  jq --arg ts "$NOW" --arg err "exit code $EXIT_CODE" \
    '.status = "error" | .error = $err' "$WATERMARK_FILE" > "${WATERMARK_FILE}.tmp" \
    && mv "${WATERMARK_FILE}.tmp" "$WATERMARK_FILE" \
    || true
fi

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

echo "$(date '+%Y-%m-%d %H:%M:%S') - Confluence monitor completed (exit code: $EXIT_CODE)."
