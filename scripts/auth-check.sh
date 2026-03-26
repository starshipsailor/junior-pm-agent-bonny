#!/bin/bash
# =============================================================================
# Bonny Auth Checker — Minimal probe to test MCP plugin OAuth status
# =============================================================================
# Runs a tiny Claude command that exercises a specific MCP plugin.
# If auth is valid, the command succeeds. If auth is stale, Claude Code
# will trigger the browser OAuth flow (when run interactively).
#
# Usage: auth-check.sh <plugin>
#   plugin: slack | notion | atlassian
#
# Modes:
#   --check   (default) Headless check — returns exit 0 if auth OK, exit 1 if not
#   --reauth  Interactive — opens in current terminal so OAuth browser flow can trigger
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PLUGIN="${1:-}"
MODE="${2:---check}"

if [ -z "$PLUGIN" ]; then
    echo "Usage: auth-check.sh <slack|notion|atlassian> [--check|--reauth]"
    exit 1
fi

# Minimal prompt per plugin — the cheapest possible call that exercises the plugin
case "$PLUGIN" in
    slack)
        PROMPT="Use the Slack MCP tool slack_search_channels to search for 'bonny-inbox' and return just the channel name. Reply with only the channel name or 'AUTH_ERROR' if auth fails."
        ;;
    notion)
        PROMPT="Use the Notion MCP tool notion-search to search for 'Meeting' with limit 1. Reply with just the page title or 'AUTH_ERROR' if auth fails."
        ;;
    atlassian)
        PROMPT="Use the Atlassian MCP tool getVisibleJiraProjects with limit 1. Reply with just the project key or 'AUTH_ERROR' if auth fails."
        ;;
    *)
        echo "Unknown plugin: $PLUGIN (expected: slack, notion, atlassian)"
        exit 1
        ;;
esac

cd "$PROJECT_ROOT"

if [ "$MODE" = "--check" ]; then
    # Headless check — capture output, check for auth errors
    OUTPUT=$(claude \
        --print \
        --model haiku \
        --max-budget-usd 0.05 \
        --permission-mode bypassPermissions \
        --mcp-config "$PROJECT_ROOT/.mcp.json" \
        --output-format text \
        -p "$PROMPT" 2>&1) || true

    # Check for auth failure patterns
    if echo "$OUTPUT" | grep -qiE "AUTH_ERROR|apiKeyHelper failed|Invalid MCP configuration|401|authentication required|OAuth|token expired|unauthorized"; then
        echo "FAIL:$PLUGIN"
        exit 1
    else
        echo "OK:$PLUGIN"
        exit 0
    fi
else
    # Interactive re-auth — run WITHOUT --print so OAuth browser flow can trigger
    echo "Triggering re-auth for $PLUGIN..."
    echo "If a browser window opens, complete the OAuth flow there."
    echo ""
    claude \
        --model haiku \
        --max-budget-usd 0.05 \
        --mcp-config "$PROJECT_ROOT/.mcp.json" \
        -p "$PROMPT"
fi
