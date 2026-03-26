#!/bin/bash
# =============================================================================
# Bonny Cleanup — Weekly archive of processed inbox items and old log entries
# =============================================================================
# Runs weekly (Sunday midnight) via launchd. Moves processed items to archive
# to keep active files lean (~100 lines max).
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
YEAR_WEEK=$(date '+%Y-%W')
YEAR_MONTH=$(date '+%Y-%m')
DATE=$(date '+%Y-%m-%d')

echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting weekly cleanup..."

# --- Archive processed inbox items (per-monitor inboxes) ---
INBOX_FILES=(
  "inbox-slack.md"
  "inbox-confluence.md"
  "inbox-meetings.md"
)
INBOX_ARCHIVE="$PROJECT_ROOT/Mission_Control/archive/inbox-${YEAR_WEEK}.md"
TOTAL_ARCHIVED=0

mkdir -p "$PROJECT_ROOT/Mission_Control/archive"

# Create archive header once
echo "---" > "$INBOX_ARCHIVE"
echo "archived: \"$DATE\"" >> "$INBOX_ARCHIVE"
echo "type: inbox-archive" >> "$INBOX_ARCHIVE"
echo "week: \"$YEAR_WEEK\"" >> "$INBOX_ARCHIVE"
echo "---" >> "$INBOX_ARCHIVE"
echo "" >> "$INBOX_ARCHIVE"
echo "# Inbox Archive — Week $YEAR_WEEK" >> "$INBOX_ARCHIVE"

for INBOX_NAME in "${INBOX_FILES[@]}"; do
  INBOX="$PROJECT_ROOT/Mission_Control/$INBOX_NAME"
  if [ ! -f "$INBOX" ]; then
    continue
  fi

  PROCESSED_COUNT=$(grep -c "Status: processed\|Status: duplicate" "$INBOX" 2>/dev/null || echo "0")

  if [ "$PROCESSED_COUNT" -gt 0 ]; then
    echo "" >> "$INBOX_ARCHIVE"
    echo "## From $INBOX_NAME" >> "$INBOX_ARCHIVE"
    echo "" >> "$INBOX_ARCHIVE"
    grep -A 10 "Status: processed\|Status: duplicate" "$INBOX" >> "$INBOX_ARCHIVE" 2>/dev/null || true

    # Remove processed/duplicate items, keep header + pending items
    python3 -c "
import re, sys
with open(sys.argv[1], 'r') as f:
    content = f.read()
sections = re.split(r'(### )', content)
result = sections[0]
i = 1
while i < len(sections):
    if i + 1 < len(sections):
        entry = sections[i] + sections[i+1]
        if 'Status: processed' not in entry and 'Status: duplicate' not in entry:
            result += entry
    i += 2
with open(sys.argv[1], 'w') as f:
    f.write(result)
" "$INBOX" 2>/dev/null || echo "Warning: Could not clean $INBOX_NAME automatically"

    TOTAL_ARCHIVED=$((TOTAL_ARCHIVED + PROCESSED_COUNT))
    echo "  Archived $PROCESSED_COUNT items from $INBOX_NAME"
  fi
done

if [ "$TOTAL_ARCHIVED" -eq 0 ]; then
  rm -f "$INBOX_ARCHIVE"
  echo "  No processed inbox items to archive"
else
  echo "  Total archived: $TOTAL_ARCHIVED items to $INBOX_ARCHIVE"
fi

# --- Archive old activity log entries ---
ACTIVITY_LOG="$PROJECT_ROOT/Mission_Control/agent_activity_log.md"
ACTIVITY_ARCHIVE="$PROJECT_ROOT/Mission_Control/archive/activity-${YEAR_MONTH}.md"

if [ -f "$ACTIVITY_LOG" ]; then
  LINE_COUNT=$(wc -l < "$ACTIVITY_LOG" | tr -d ' ')
  if [ "$LINE_COUNT" -gt 100 ]; then
    mkdir -p "$PROJECT_ROOT/Mission_Control/archive"
    cp "$ACTIVITY_LOG" "$ACTIVITY_ARCHIVE"
    # Keep header (first 8 lines) and last 20 entries
    head -8 "$ACTIVITY_LOG" > "$ACTIVITY_LOG.tmp"
    tail -20 "$ACTIVITY_LOG" >> "$ACTIVITY_LOG.tmp"
    mv "$ACTIVITY_LOG.tmp" "$ACTIVITY_LOG"
    echo "  Trimmed activity log (was $LINE_COUNT lines)"
  fi
fi

# --- Archive old action log entries ---
ACTION_LOG="$PROJECT_ROOT/Outputs_and_Self_Improvement/action_log.md"
ACTION_ARCHIVE="$PROJECT_ROOT/Outputs_and_Self_Improvement/archive/actions-${YEAR_MONTH}.md"

if [ -f "$ACTION_LOG" ]; then
  LINE_COUNT=$(wc -l < "$ACTION_LOG" | tr -d ' ')
  if [ "$LINE_COUNT" -gt 100 ]; then
    mkdir -p "$PROJECT_ROOT/Outputs_and_Self_Improvement/archive"
    cp "$ACTION_LOG" "$ACTION_ARCHIVE"
    head -10 "$ACTION_LOG" > "$ACTION_LOG.tmp"
    tail -20 "$ACTION_LOG" >> "$ACTION_LOG.tmp"
    mv "$ACTION_LOG.tmp" "$ACTION_LOG"
    echo "  Trimmed action log (was $LINE_COUNT lines)"
  fi
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Weekly cleanup completed."
