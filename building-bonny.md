# Building Bonny — Complete Project Status & Context

> **Purpose of this file:** Give any new Claude Code session full context to pick up where the last one left off. Read this before doing anything.

---

## What Is Bonny?

A multi-agent PM assistant for Rohan Vadgaonkar (Product Director, Wise Business). Bonny monitors Slack, Confluence, and Notion meeting notes, processes them through an orchestrator, and maintains a team-centric Obsidian vault as a knowledge graph.

Bonny behaves like a junior PM: surfaces what matters, flags risks, drafts communications — but never makes decisions or sends messages on Rohan's behalf.

## Architecture (v2 — Current)

```
Slack channels ─────────┐
Confluence pages ───────┤  (3 monitor scripts, each writes to its own inbox)
Notion meeting notes ───┘
            ↓
    Mission_Control/inbox-slack.md
    Mission_Control/inbox-confluence.md
    Mission_Control/inbox-meetings.md
            ↓
    Bonny orchestrator          (processes all inboxes per operating_guidelines.md)
            ↓
    ┌───────┼───────────┬──────────────┐
    ↓       ↓           ↓              ↓
 Vault    Slack       Confluence    Questions
 updates  drafts      pages         for Rohan
```

Key v2 design decisions:
- **Per-monitor inboxes** — eliminates race conditions from concurrent writes
- **Skills-as-markdown** — detailed instructions in `.claude/commands/skills/*.md`, shell scripts are thin runners
- **Watermark pattern** — `state/*-last-run.json` for idempotent scanning
- **Daily context digest** — monitors load `state/context-digest.md` (~200 lines) instead of ~30 vault files
- **Budget gate** — $50/day cap tracked in `state/daily-spend.json`
- **Self-improvement loop** — diffs Bonny's drafts vs what Rohan actually sent

---

## File Inventory

### Core Config
| File | Purpose | Status |
|------|---------|--------|
| `CLAUDE.md` | Agent brain — identity, vault structure, skills, workflow phases, rules | Current (v2) |
| `.mcp.json` | MCP server config (Notion, Calendar, Desktop, Atlassian) | Current |
| `.claude/settings.json` | Slack plugin enabled | Current |
| `config/bonny.json` | Channel mappings (with priority tiers + slack_id), Confluence watch pages, budget cap | Current (v2) |
| `config/secrets.env` | NOTION_TOKEN (gitignored) | Placeholder — Rohan to fill |
| `operating_guidelines.md` | Decision framework: routing rules, confidence calibration, channel priorities, dedup | Current (v2) |

### Skills (`.claude/commands/skills/`)
| Skill | Purpose |
|-------|---------|
| `slack-monitor-skill.md` | 3 Slack criteria: DMs, @mentions, priority channels. Classifies 6 action types |
| `confluence-monitor-skill.md` | Check lastModified vs watermark, read project context before summarizing |
| `meeting-monitor-skill.md` | Query Notion DB, match attendees, extract structured data |
| `draft-slack.md` | Compose drafts to `state/slack-drafts/`, NEVER auto-send |
| `write-confluence.md` | Draft to `state/confluence-drafts/` for review before MCP call |
| `update-vault.md` | Navigate vault for project/people/KPI updates, maintain wikilinks |
| `update-tasks.md` | Obsidian task format, append-only rules |
| `read-calendar.md` | Read-only calendar access, cross-reference with people index |

### Slash Commands (`.claude/commands/`)
| Command | Purpose |
|---------|---------|
| `/monitor-now` | Run all 3 monitors in one interactive pass (references skill files) |
| `/process-inbox` | Process pending items across all 3 inbox files per operating guidelines |
| `/vault-maintenance` | Consistency check: wikilinks, frontmatter, cross-refs, staleness |

### Scripts (`scripts/`)
| Script | Purpose | Schedule |
|--------|---------|----------|
| `bonny-run.sh` | Orchestrator — processes all 3 inboxes, health-checks monitors | Every 1 hour |
| `monitor-slack.sh` | Thin runner: budget gate, watermark, invokes skill file | Every 30 min |
| `monitor-confluence.sh` | Thin runner: budget gate, watermark, invokes skill file | Every 2 hours |
| `monitor-meetings.sh` | Thin runner: budget gate, watermark, invokes skill file | Every 1 hour |
| `generate-context-digest.sh` | Produces `state/context-digest.md` from vault | Daily at 6am |
| `self-improvement.sh` | Diffs drafts vs sent, proposes skill updates | Daily at 7am |
| `cleanup-archives.sh` | Archives processed items from all 3 inboxes | Weekly (Sunday) |
| `install.sh` | Install all 7 launchd agents | One-time |
| `slack-draft.sh` | AppleScript: open Slack with pre-filled draft | Manual |

All monitor scripts invoke `claude --print --permission-mode bypassPermissions --model sonnet`.

### launchd Plists (project root)
| Plist | Script | Interval |
|-------|--------|----------|
| `com.bonny.pm-agent.plist` | `bonny-run.sh` | 3600s (1hr) |
| `com.bonny.slack-monitor.plist` | `monitor-slack.sh` | 1800s (30min) |
| `com.bonny.confluence-monitor.plist` | `monitor-confluence.sh` | 7200s (2hr) |
| `com.bonny.meeting-monitor.plist` | `monitor-meetings.sh` | 3600s (1hr) |
| `com.bonny.cleanup.plist` | `cleanup-archives.sh` | Weekly |
| `com.bonny.context-digest.plist` | `generate-context-digest.sh` | Daily at 6am |
| `com.bonny.self-improvement.plist` | `self-improvement.sh` | Daily at 7am |

### State Files (`state/`)
| File | Purpose |
|------|---------|
| `slack-monitor-last-run.json` | Watermark for Slack monitor |
| `confluence-monitor-last-run.json` | Watermark for Confluence monitor |
| `meeting-monitor-last-run.json` | Watermark for meeting monitor |
| `daily-spend.json` | Budget tracking ($50/day cap) |
| `context-digest.md` | Condensed vault context (~200 lines) |
| `processed.log` | Meeting page IDs already processed |
| `slack-drafts/` | Drafted Slack messages for Rohan's review |

### Templates (`templates/`) — 9 files
`meeting-summary.md`, `task-list.md`, `slack-followup.md`, `daily-briefing.md`, `session-log.md`, `person_template.md`, `team_kpis_template.md`, `team_people_template.md`, `team_projects_charter_template.md`

---

## MCP Servers (5 total)

| Server | Type | Config Location |
|--------|------|-----------------|
| **Notion** | Local stdio (`npx @notionhq/notion-mcp-server`) | `.mcp.json` |
| **Apple Calendar** | Local stdio (`uvx mcp-ical`) | `.mcp.json` |
| **Desktop** | Local stdio (`npx native-devtools-mcp`) | `.mcp.json` |
| **Atlassian** | Remote HTTP (`https://mcp.atlassian.com/v1/mcp`) | `.mcp.json` |
| **Slack** | Plugin (`slack@claude-plugins-official`) | `.claude/settings.json` |

**Slack gotcha:** Wise org blocks bot/app creation. The Slack MCP MUST use the Claude Code plugin (`/plugin slack`), NOT a remote HTTP MCP. The HTTP endpoint at `mcp.slack.com/sse` fails with "does not support dynamic client registration". This was debugged and resolved on 2026-03-22.

---

## Vault Structure

```
Business_Chapter/                          # 55 .md files total
  chapter_strategy.md                      # Overarching Wise Business strategy
  chapter_kpis.md                          # Chapter-level KPI targets
  chapter_ceremonies.md                    # Operating rhythm
  chapter_hiring.md                        # Hiring pipeline
  chapter_projects/                        # 6 files: relevance-study, mini_projects, etc.
  Business_Account_Squad/                  # Squad with 6 teams
    bas_squad_info.md
    BAX/       (bax_kpis, bax_people, bax_projects/: 1 project)
    BAM/       (bam_kpis, bam_people, bam_projects/: 2 projects)
    AIR/       (air_kpis, air_people, air_projects/: 3 projects)
    Account_Specialist_Tooling/ (ast_*: 1 project)
    Biz_Plans_Pricing/          (bpp_*: 4 projects)
    BizOn/                      (bizon_*: 2 projects)
  Acquiring_Squad/                         # Squad with 3 teams
    acq_squad_info.md
    Acquiring_Platform/ (acqp_*: 2 projects)
    Acquiring_Risk/     (acqr_*: 1 project)
    Getpaid_Formats/    (gpf_*: 2 projects)
  Account_Payables/                        # Virtual squad, 2 teams
    ap_squad_info.md
    Business_Send/ (bsend_*: 1 project)
    BEM/           (bem_*: 1 project)
People/
  Global_people_index.md                   # Master lookup: name, role, team, slack, link
  individual_people/                       # 101 person files
Opportunities/                             # Early-stage ideas
  opportunities_index.md
Mission_Control/
  inbox-slack.md                           # Slack monitor writes here
  inbox-confluence.md                      # Confluence monitor writes here
  inbox-meetings.md                        # Meeting monitor writes here
  inbox.md                                 # Format documentation only
  agent_activity_log.md
  handoff_queue.md
  archive/
Outputs_and_Self_Improvement/
  action_log.md                            # Every Bonny action logged here
  questions_for_rohan.md                   # Low-confidence items + Slack DMs
  self_improvement_reviews/
  archive/
Session-Logs/                              # NOTE: hyphen, not underscore
```

Each team folder follows: `prefix_kpis.md`, `prefix_people.md`, `prefix_projects_charter.md`, `prefix_projects/*.md`

### Link Conventions
- **People**: `[[Firstname_Lastname_Team]]` -> `People/individual_people/`
- **Projects**: `[[filename]]` e.g. `[[accounting-integrations]]`
- **Team docs**: `[[bax_kpis]]`, `[[bax_people]]`, `[[bax_projects_charter]]`
- **Squad/chapter**: `[[bas_squad_info]]`, `[[chapter_strategy]]`, `[[chapter_kpis]]`

---

## What's Been Built (Complete)

1. **Full v2 vault** — 55 business chapter files, 101 people files, 26 project files across 12 project directories
2. **CLAUDE.md** — v2 agent brain with skills system, scheduled agents, workflow phases, rules
3. **operating_guidelines.md** — Expanded decision framework: routing rules, channel priorities, confidence calibration, dedup
4. **config/bonny.json** — 12 Slack channels with priority tiers + slack_id fields, 14 Confluence watch pages, $50/day budget cap
5. **.mcp.json** — 4 MCP servers (Notion, Calendar, Desktop, Atlassian)
6. **Slack plugin** — Authenticated via OAuth, working as of 2026-03-22
7. **8 skill files** — 3 monitor skills + 5 action skills in `.claude/commands/skills/`
8. **9 scripts** — 3 monitor thin runners, orchestrator, context digest, self-improvement, cleanup, install, slack-draft
9. **7 launchd plists** — All monitors + orchestrator + cleanup + context digest + self-improvement
10. **3 watermark state files** — Per-monitor idempotent scanning
11. **Budget tracking** — `state/daily-spend.json` with $50/day cap enforced in all scripts
12. **Per-monitor inboxes** — inbox-slack.md, inbox-confluence.md, inbox-meetings.md (eliminates race conditions)
13. **9 templates** — Meeting summary, task list, Slack followup, daily briefing, session log, person, team KPIs, team people, team projects charter
14. **3 slash commands** — `/monitor-now`, `/process-inbox`, `/vault-maintenance`
15. **Mission Control** — Per-monitor inboxes, activity log, handoff queue, archive directory
16. **README.md** — v2 setup guide with architecture diagram
17. **Self-improvement loop** — Daily review at 7am, diffs drafts vs sent, proposes skill updates
18. **Context digest** — Daily at 6am, condenses vault to ~200 lines for monitors
19. **Archive system** — v1 stale files moved to `Archive/`

---

## Gotchas for New Sessions
- **Session-Logs** uses a hyphen, not underscore. CLAUDE.md was fixed but double-check.
- **Slack MCP** requires plugin, not HTTP. If you see errors about "dynamic client registration", the fix is `/plugin slack`.
- **Wikilinks** were audited and fixed on 2026-03-22. All 9 project files had broken links redirected to correct targets. Run `/vault-maintenance` to re-check.
- **v1 files** are in `Archive/` — `bonny-plan-v1.md`, `PLAN-v1.md`, `generate-context-v1.sh`. Don't read these for current architecture.

---

## How to Work on This Project

### If asked to process meetings or monitor channels:
1. Read `operating_guidelines.md` for the decision framework
2. Read `config/bonny.json` for channel/page mappings
3. Check all 3 inbox files in `Mission_Control/` for pending items
4. Use the slash commands: `/monitor-now`, `/process-inbox`

### If asked to update the vault:
1. Read `CLAUDE.md` for link conventions and structure
2. Read the relevant team's `*_projects_charter.md` for project context
3. Read `People/Global_people_index.md` if you need to identify someone
4. Update `last_updated` in YAML frontmatter of any file you change

### If asked to check vault health:
1. Run `/vault-maintenance`
2. Or manually: check wikilinks resolve, frontmatter is complete, cross-refs are consistent

### If asked about strategy, KPIs, or org structure:
1. `Business_Chapter/chapter_strategy.md` — top-level goals
2. `Business_Chapter/chapter_kpis.md` — KPI targets
3. Squad info files: `bas_squad_info.md`, `acq_squad_info.md`, `ap_squad_info.md`

---

## What's Left To Do (Prioritized)

### P1 — Should do soon
1. **Fill in secrets**: Paste Notion token into `config/secrets.env`
2. **Fill in Slack channel IDs**: Look up IDs for private channels, fill `slack_id` fields in `config/bonny.json`
3. **End-to-end test**: Run each monitor script once manually to verify they work with real Slack/Confluence/Notion data
4. **Install launchd agents**: Run `scripts/install.sh` to activate scheduled monitoring

### P2 — Nice to have
5. **Daily briefing generation**: Template exists but no automation triggers it
6. **Google Calendar API**: Apple Calendar MCP is read-only. Google Calendar integration for write access is a future item.

---

*Last updated: 2026-03-22*
