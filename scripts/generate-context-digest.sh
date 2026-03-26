#!/bin/bash
# =============================================================================
# Bonny Context Digest Generator — Pre-compiles vault context into a summary
# =============================================================================
# Runs daily at 6am via launchd. Reads key vault files and produces a condensed
# ~200-line digest at state/context-digest.md that monitors use instead of
# loading ~30 files on every run.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_DIR="$PROJECT_ROOT/state"
LOG_DIR="$PROJECT_ROOT/logs"
SECRETS_FILE="$PROJECT_ROOT/config/secrets.env"
MAX_BUDGET="1.00"

mkdir -p "$STATE_DIR" "$LOG_DIR"

# --- Source secrets ---
if [ -f "$SECRETS_FILE" ]; then
  set -a
  source "$SECRETS_FILE"
  set +a
fi

# --- Check prerequisites ---
if ! command -v claude &> /dev/null; then
  echo "ERROR: Claude Code CLI not found." >&2
  exit 1
fi

# --- Build prompt ---
PROMPT="You are the Bonny Context Digest Generator. Your job is to read the vault and produce a condensed summary file.

Read the following files:
1. config/bonny.json (channel mappings, Confluence pages)
2. operating_guidelines.md (decision framework summary)
3. Business_Chapter/chapter_strategy.md (strategy pillars)
4. People/Global_people_index.md (people quick-reference)
5. All *_projects_charter.md files across all teams (active project summaries)
6. All *_kpis.md files across all teams (current metrics)

Then write a condensed digest to state/context-digest.md with these sections:

## Strategy Summary
3-5 bullet points from chapter_strategy.md

## Channel-Team Mapping
Table: Channel | Team | Squad | Priority | Charter File
(from bonny.json slack_channels)

## Active Projects
Table: Project | Team | Status | PM | Target Date | Key Context
(from all *_projects_charter.md — only in-progress projects)

## People Quick-Reference
Table: Name | Role | Team | Slack
(from Global_people_index.md — top 30 most relevant people)

## Key KPI Snapshot
Table: Team | North Star Metric | Current Value | Target
(from all *_kpis.md)

## Confluence Watch Pages
Table: Label | Project | URL
(from bonny.json confluence_watch_pages)

## Operating Guidelines Summary
- Decision types and routing rules (condensed from operating_guidelines.md)
- Priority tiers

Keep the total output under 250 lines. This file is loaded by monitors to avoid reading 30+ files on every run."

# --- Run Claude Code ---
LOG_FILE="$LOG_DIR/context-digest-$(date '+%Y-%m-%d_%H%M%S').log"

echo "$(date '+%Y-%m-%d %H:%M:%S') - Generating context digest..."

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

echo "$(date '+%Y-%m-%d %H:%M:%S') - Context digest generation completed (exit code: $EXIT_CODE)."
