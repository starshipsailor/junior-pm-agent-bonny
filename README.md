# Bonny — Multi-Agent PM Assistant

Bonny is an autonomous PM assistant built on [Claude Code](https://claude.ai/code). It runs as a set of scheduled agents that monitor Slack, Confluence, and Notion meeting notes, then processes findings through an orchestrator that updates a team-centric knowledge vault, drafts Slack messages, and logs actions for self-improvement.

Built for a Product Director managing multiple squads and 11+ teams. The system handles the information firehose — surfacing what matters, flagging risks, drafting communications — while keeping a human in the loop for all decisions.

## Architecture

```
Slack channels ─────────┐
Confluence pages ───────┤  (3 monitors run on schedule via launchd)
Notion meeting notes ───┘
            |
    Per-monitor inboxes (inbox-slack.md, inbox-confluence.md, inbox-meetings.md)
            |
    Orchestrator (processes inbox items by priority, executes actions via skill files)
            |
    ┌───────┼───────────┬──────────────┐
    |       |           |              |
 Vault    Slack       Confluence    Task list
 updates  drafts      pages         updates
            |
    #bonny-inbox channel (human reviews all drafts before sending)
```

### Agents

| Agent | Script | Schedule | Budget | Purpose |
|-------|--------|----------|--------|---------|
| Slack Monitor | `monitor-slack.sh` | Every 30 min | $2 | 5-pass priority scan: inbox replies, DMs, @mentions, threads, channel scan |
| Confluence Monitor | `monitor-confluence.sh` | Every 2 hours | $2 | Watches configured pages for changes |
| Meeting Monitor | `monitor-meetings.sh` | Every 1 hour | $3 | Processes Notion meeting notes, extracts action items |
| Orchestrator | `bonny-run.sh` | Every 1 hour | $5 | Reads all 3 inboxes, routes by priority, takes actions |
| Context Digest | `generate-context-digest.sh` | Daily 6am | $1 | Pre-compiles vault summary for faster agent startup |
| Self-Improvement | `self-improvement.sh` | Daily 7am | $3 | Diffs Bonny's drafts vs what was actually sent, identifies patterns |
| Cleanup | `cleanup-archives.sh` | Weekly Sunday | — | Archives processed inbox items |

### Skills System

Skills are markdown instruction files that define *how* to perform specific tasks. They live in `.claude/commands/skills/`:

| Skill | Purpose |
|-------|---------|
| `slack-monitor-skill.md` | 5-pass Slack scanning with priority channels, DMs, mentions, threads |
| `confluence-monitor-skill.md` | Check watched Confluence pages for changes |
| `meeting-monitor-skill.md` | Process Notion meeting notes with attendee matching |
| `draft-slack.md` | Compose Slack drafts, post to review channel |
| `write-confluence.md` | Create/update Confluence pages via Atlassian MCP |
| `update-vault.md` | Navigate vault structure, update files, maintain wikilinks |
| `update-tasks.md` | Add/complete/block tasks in Obsidian format |
| `read-calendar.md` | Read calendar/meeting data via Notion |

### BonnyMonitor — macOS Menubar App

A native SwiftUI menubar app (`BonnyMonitor/`) for real-time visibility:

- **Agent status** with color-coded dots (green=scheduled, blue=running, orange=paused, yellow=budget-paused, red=error)
- **Per-agent details**: watermark state, budget per run, recent 5 runs, error messages
- **Run/Pause controls**: trigger any agent or pause/resume via launchctl
- **Budget gauge**: `$spent/$cap` with per-agent cost breakdown
- **Temporary budget override**: 2x for today only (writes `state/budget-override.json`, auto-expires)
- **Auth status**: per-plugin health check with re-auth trigger for OAuth plugins

Built with SwiftUI `MenuBarExtra`, XcodeGen for project generation.

## Vault Structure

The knowledge graph is an Obsidian vault organized by team hierarchy:

```
Business_Chapter/
  chapter_strategy.md, chapter_kpis.md, chapter_ceremonies.md, chapter_hiring.md
  chapter_projects/              # Cross-cutting projects
  Business_Account_Squad/        # Squad with N teams
    bas_squad_info.md
    TeamA/  (teama_kpis.md, teama_people.md, teama_projects/)
    TeamB/  ...
  Another_Squad/
    ...
People/
  Global_people_index.md         # Master lookup: name, role, team, slack handle
  individual_people/             # Per-person files
Opportunities/                   # Early-stage ideas
Mission_Control/                 # Per-monitor inboxes, activity log
  inbox-slack.md
  inbox-confluence.md
  inbox-meetings.md
  agent_activity_log.md
Outputs_and_Self_Improvement/    # Action log, questions, self-improvement reviews
```

## Prerequisites

- macOS (launchd scheduling)
- [Claude Code CLI](https://claude.ai/code) installed and authenticated
- [jq](https://jqlang.github.io/jq/) — `brew install jq`
- MCP server access:
  - **Slack** — via Claude Code plugin (`/plugin slack`)
  - **Atlassian/Confluence** — via [Atlassian MCP](https://mcp.atlassian.com) (HTTP remote)
  - **Notion** — via Claude Code plugin (`/plugin notion`)

For the BonnyMonitor app:
- Xcode 15+ / Swift 5.9
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

## Setup

### 1. Clone and configure

```bash
git clone https://github.com/YOUR_USERNAME/junior-pm-agent-bonny.git
cd junior-pm-agent-bonny

# Copy example config and fill in your values
cp config/bonny.example.json config/bonny.json
```

Edit `config/bonny.json` with:
- `obsidian_vault_path` — absolute path to this directory
- `notion_meeting_notes_db` — your Notion database ID
- `slack_channels` — channels to monitor, mapped to your team structure
- `confluence_watch_pages` — Confluence pages to watch
- `bonny_inbox_channel` — private Slack channel for Bonny's drafts

### 2. Create secrets file

```bash
cat > config/secrets.env << 'EOF'
# Add any API tokens needed by your MCP servers
NOTION_TOKEN=ntn_your_token_here
EOF
```

### 3. Connect MCP servers

```bash
# In Claude Code:
/plugin slack      # Follow OAuth flow
/plugin notion     # Follow OAuth flow
```

The `.mcp.json` file configures Atlassian (HTTP remote) and Desktop automation. Slack and Notion use OAuth plugins.

### 4. Build your vault

Create the vault directory structure for your organization. See `CLAUDE.md` for the full structure and naming conventions.

### 5. Test

```bash
# Dry run — check config without running Claude
./scripts/bonny-run.sh --dry-run

# Run a single monitor
./scripts/monitor-slack.sh

# Run the orchestrator
./scripts/bonny-run.sh
```

### 6. Install scheduled agents

```bash
./scripts/install.sh
```

This installs 7 launchd agents to `~/Library/LaunchAgents/`.

### 7. Build BonnyMonitor (optional)

```bash
cd BonnyMonitor
xcodegen generate
./build.sh
```

## How It Works

### Monitor → Inbox → Orchestrator → Action

1. **Monitors** run on schedule, scan their source (Slack/Confluence/Notion), and write structured entries to per-monitor inbox files
2. **Orchestrator** reads all 3 inboxes, sorts pending items by priority (BLOCKER > ACTION_ITEM > DECISION > STATUS_CHANGE > PERSONNEL > RISK), and routes each to the appropriate action skill
3. **Actions** update the vault, draft Slack messages, create Confluence pages, or log questions
4. **Self-improvement** agent reviews daily — diffs Bonny's drafts against what was actually sent, identifies patterns, proposes guideline updates

### Budget System

All agents have per-run budgets and a shared daily cap ($50 default). Budget tracking via `state/daily-spend.json`. Temporary 2x overrides via the BonnyMonitor app write to `state/budget-override.json` (auto-expires daily).

### Auth Management

OAuth plugins (Slack, Notion) may expire. `scripts/auth-check.sh` provides:
- `--check` mode: headless probe ($0.05) to test each plugin
- `--reauth` mode: opens interactive Terminal to trigger browser OAuth flow

The BonnyMonitor app surfaces auth status and provides one-click re-auth.

### Human in the Loop

Bonny never sends messages or makes decisions autonomously. All Slack drafts go to `#bonny-inbox` for review. Low-confidence items are logged as questions. The self-improvement loop learns from corrections.

## Slash Commands

When using Claude Code interactively in this project:

| Command | Purpose |
|---------|---------|
| `/monitor-now` | Run all 3 monitors in one interactive pass |
| `/process-inbox` | Process pending items across all inboxes |
| `/vault-maintenance` | Vault consistency check (broken links, stale data) |

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Runtime | Claude Code CLI (`claude --print`) | Skills-as-markdown, MCP access, no custom code needed |
| Knowledge graph | Obsidian vault with wikilinks | Team-centric structure, human-readable, versionable |
| Agent architecture | Independent monitors + orchestrator | Prevents context overload, each agent stays focused |
| Inbox pattern | Monitors write, orchestrator processes | Decouples discovery from action |
| Slack approach | Draft to review channel, never auto-send | Human retains full control |
| Budget | Per-run + daily cap + temporary override | Prevents cost spirals without blocking urgent work |
| Self-improvement | Action log + draft diff tracking | System learns from human corrections over time |
| Scheduling | macOS launchd | Native, reliable, no external dependencies |

## Project Structure

```
scripts/                    # Shell scripts for all agents
  bonny-run.sh              # Main orchestrator
  monitor-slack.sh          # Slack monitor
  monitor-confluence.sh     # Confluence monitor
  monitor-meetings.sh       # Meeting monitor
  generate-context-digest.sh # Daily context compilation
  self-improvement.sh       # Daily self-review
  cleanup-archives.sh       # Weekly archive
  auth-check.sh             # Auth probe + re-auth
  install.sh                # launchd plist installer
config/
  bonny.example.json        # Template configuration
  secrets.env               # API tokens (gitignored)
  bonny.json                # Your config (gitignored)
.claude/
  commands/                 # Slash commands
    skills/                 # 8 skill files (3 monitor + 5 action)
BonnyMonitor/               # macOS menubar app (SwiftUI)
  App/                      # Entry point + state management
  Models/                   # Agent definitions, status, budget
  Services/                 # File system, launchd, log parsing
  Views/                    # UI components
  project.yml               # XcodeGen spec
state/                      # Runtime state (gitignored)
  daily-spend.json          # Budget tracking
  *-last-run.json           # Per-monitor watermarks
  budget-override.json      # Temporary budget override
  slack-drafts/             # Draft message backups
  context-digest.md         # Pre-compiled vault summary
com.bonny.*.plist           # launchd agent definitions
operating_guidelines.md     # Decision framework, routing rules
CLAUDE.md                   # Agent instructions
```

## License

MIT
