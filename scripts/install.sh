#!/bin/bash
# =============================================================================
# Install Bonny v2 — Multi-Agent PM System as launchd services
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENTS_DIR="$HOME/Library/LaunchAgents"

echo "=== Installing Bonny v2 — Multi-Agent PM System ==="
echo ""

# --- Check prerequisites ---
MISSING=()

if ! command -v claude &> /dev/null; then
  MISSING+=("claude (Claude Code CLI)")
fi

if ! command -v jq &> /dev/null; then
  MISSING+=("jq (brew install jq)")
fi

if ! command -v python3 &> /dev/null; then
  MISSING+=("python3 (for cleanup script)")
fi

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "ERROR: Missing prerequisites:" >&2
  for m in "${MISSING[@]}"; do
    echo "  - $m" >&2
  done
  exit 1
fi

if [ ! -f "$PROJECT_ROOT/config/bonny.json" ]; then
  echo "WARNING: config/bonny.json not found." >&2
  echo "  Meeting monitor requires this. Other monitors will still work." >&2
  echo ""
fi

# --- Create directories ---
mkdir -p "$PROJECT_ROOT/state" "$PROJECT_ROOT/logs" "$PROJECT_ROOT/state/slack-drafts"
mkdir -p "$PROJECT_ROOT/Mission_Control/archive"
mkdir -p "$PROJECT_ROOT/Outputs_and_Self_Improvement/archive"
mkdir -p "$AGENTS_DIR"

# --- Define all plists ---
PLISTS=(
  "com.bonny.pm-agent"
  "com.bonny.slack-monitor"
  "com.bonny.confluence-monitor"
  "com.bonny.meeting-monitor"
  "com.bonny.cleanup"
  "com.bonny.context-digest"
  "com.bonny.self-improvement"
)

# --- Install each plist ---
for PLIST in "${PLISTS[@]}"; do
  SOURCE="$PROJECT_ROOT/${PLIST}.plist"
  DEST="$AGENTS_DIR/${PLIST}.plist"

  if [ ! -f "$SOURCE" ]; then
    echo "  SKIP: $SOURCE not found"
    continue
  fi

  launchctl unload "$DEST" 2>/dev/null || true
  cp "$SOURCE" "$DEST"
  launchctl load "$DEST"
  echo "  Installed and loaded: $PLIST"
done

echo ""
echo "=== Bonny v2 is now running ==="
echo ""
echo "Agents installed:"
echo "  - com.bonny.pm-agent           (main orchestrator, every 1 hour)"
echo "  - com.bonny.slack-monitor      (Slack scanning, every 30 min)"
echo "  - com.bonny.confluence-monitor (Confluence watching, every 2 hours)"
echo "  - com.bonny.meeting-monitor    (Notion meeting notes, every 1 hour)"
echo "  - com.bonny.cleanup            (weekly archive, Sunday midnight)"
echo "  - com.bonny.context-digest     (daily context digest, 6am)"
echo "  - com.bonny.self-improvement   (daily self-improvement review, 7am)"
echo ""
echo "Useful commands:"
echo ""
echo "  # Check all agent status"
echo "  launchctl list | grep bonny"
echo ""
echo "  # Run a monitor immediately"
echo "  launchctl start com.bonny.slack-monitor"
echo "  launchctl start com.bonny.confluence-monitor"
echo "  launchctl start com.bonny.meeting-monitor"
echo ""
echo "  # Run main agent manually"
echo "  ./scripts/bonny-run.sh"
echo ""
echo "  # View logs"
echo "  tail -f $PROJECT_ROOT/logs/slack-monitor-stdout.log"
echo ""
echo "  # Stop all agents"
echo "  for p in ${PLISTS[*]}; do launchctl unload ~/Library/LaunchAgents/\$p.plist 2>/dev/null; done"
echo ""
