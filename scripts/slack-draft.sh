#!/bin/bash
# =============================================================================
# Slack Draft Message via AppleScript
# =============================================================================
# Opens a Slack DM to a specific person and pre-fills a message for review.
# The message is NOT sent automatically — the user must press Enter to send.
#
# Usage:
#   ./scripts/slack-draft.sh "@john.smith" "path/to/draft.md"
#   ./scripts/slack-draft.sh "#channel-name" "path/to/draft.md"
#
# Requirements:
#   - Slack desktop app installed and logged in
#   - macOS (uses AppleScript via osascript)
#   - Accessibility access granted to Terminal/iTerm in
#     System Settings > Privacy & Security > Accessibility
# =============================================================================

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <slack-handle-or-channel> <draft-file-path>" >&2
  exit 1
fi

RECIPIENT="$1"
DRAFT_FILE="$2"

if [ ! -f "$DRAFT_FILE" ]; then
  echo "ERROR: Draft file not found: $DRAFT_FILE" >&2
  exit 1
fi

# Read message body only (skip the metadata header lines)
MESSAGE=$(awk '/^---$/{if(++n==2){found=1;next}} found{print}' "$DRAFT_FILE")

# Fallback: if no --- delimiters found, use the whole file
if [ -z "$MESSAGE" ]; then
  MESSAGE=$(cat "$DRAFT_FILE")
fi

# Trim leading/trailing whitespace
MESSAGE=$(echo "$MESSAGE" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

if [ -z "$MESSAGE" ]; then
  echo "ERROR: Draft file is empty or contains only metadata: $DRAFT_FILE" >&2
  exit 1
fi

# Escape for AppleScript
MESSAGE_ESCAPED=$(echo "$MESSAGE" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')

osascript - "$RECIPIENT" "$MESSAGE_ESCAPED" <<'APPLESCRIPT'
on run argv
    set recipientName to item 1 of argv
    set messageText to item 2 of argv

    -- Activate Slack
    tell application "Slack" to activate
    delay 1

    -- Use Cmd+K to open the quick switcher
    tell application "System Events"
        tell process "Slack"
            keystroke "k" using command down
            delay 0.5

            -- Type the recipient name/channel
            keystroke recipientName
            delay 1

            -- Press Enter to open the conversation
            keystroke return
            delay 1

            -- Paste the message via clipboard
            set the clipboard to messageText
            keystroke "v" using command down
        end tell
    end tell

    -- Message is NOT sent. User must review and press Enter.
end run
APPLESCRIPT

OSASCRIPT_STATUS=$?

if [ $OSASCRIPT_STATUS -ne 0 ]; then
  echo "WARNING: AppleScript failed (status $OSASCRIPT_STATUS)." >&2
  echo "The draft message is saved at: $DRAFT_FILE" >&2
  echo "You can copy it manually." >&2
  exit $OSASCRIPT_STATUS
fi

echo "Draft prepared in Slack for $RECIPIENT. Review and press Enter to send."
exit 0
