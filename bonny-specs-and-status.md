# Bonny v2 — Specs & Status

*Created: 2026-03-22*
*Last updated: 2026-03-26 — ALL 7 BUILD PHASES COMPLETE. System deployed and running. BonnyMonitor menubar app built. Schedules optimized. Open-sourced.*

## Context

Bonny is a multi-agent PM assistant. The previous session built ~60% — the full vault (55 business files, 101 people, 26 projects), config, templates, and basic scripts. But the runtime system had critical issues: monitors wrote to a shared inbox (race condition), the orchestrator still ran a v1 meeting-processing prompt, there were no watermarks so monitors re-read data, and the Slack-specific criteria from Rohan's original spec were never implemented. This plan completed the remaining ~40% with all 14 architectural fixes baked in.

---

## Architecture Fixes Incorporated

| # | Issue | Severity | Fix | Status |
|---|-------|----------|-----|--------|
| C1 | Slack plugin in --print mode | Critical | **Intermittent** — OAuth plugins sometimes work in `--print` mode (confirmed working Mar 23–26), sometimes fail. Slack monitor skill rewritten to use 5-pass priority scan (bonny-inbox → DMs → mentions → threads → channels). Headless reliability still inconsistent. | PARTIAL |
| C2 | No watermark for monitors | Critical | `state/{monitor}-last-run.json` per monitor | DONE |
| C3 | Concurrent inbox writes | Critical | Split into per-monitor inbox files | DONE |
| C4 | bonny-run.sh is wrong role | Critical | Rewritten as inbox processor/orchestrator | DONE |
| H1 | Vague monitor prompts | High | Detailed skill files in `.claude/commands/skills/` | DONE |
| H2 | No deduplication | High | Entity-based dedup instructions in skill files | DONE |
| H3 | Expensive context loading | High | Daily `state/context-digest.md` via generate-context-digest.sh | DONE |
| M1 | No failure alerting | Medium | Health check in orchestrator (checks watermark staleness) | DONE |
| M2 | Budget spiral | Medium | Daily spend tracking in state/daily-spend.json, $50/day cap in all scripts | DONE |
| M3 | Self-improvement not built | Medium | Daily diff agent (self-improvement.sh) + Slack DM reminders | DONE |
| M4 | No action skills | Medium | 5 skill files in `.claude/commands/skills/` | DONE |
| M5 | Thin operating guidelines | Medium | Priority tiers, confidence examples, routing rules, dedup rules added | DONE |
| L1 | Fragile cleanup script | Low | Safer per-monitor inbox processing, handles duplicate status | DONE |
| L5 | No priority tiers | Low | Added to bonny.json with P1/P2 and slack_id fields | DONE |
| L7 | Duplicate last_updated frontmatter | Low | Removed from all 13 affected project files | DONE |

---

## Phase 1: Foundation — COMPLETE

### 1.1 Split inbox into per-monitor files (fixes C3) — DONE
- `Mission_Control/inbox-slack.md` — 2 existing Slack items migrated
- `Mission_Control/inbox-confluence.md` — 2 existing Confluence items migrated
- `Mission_Control/inbox-meetings.md` — empty, header only
- `Mission_Control/inbox.md` — converted to format documentation only

### 1.2 Create watermark state files (fixes C2) — DONE
- `state/slack-monitor-last-run.json`
- `state/confluence-monitor-last-run.json`
- `state/meeting-monitor-last-run.json`
- Format: `{"last_success": null, "items_found": 0, "items_written": 0, "status": "initialized", "error": null}`

### 1.3 Create `config/secrets.env` — DONE
- Created with placeholder, Rohan filled in Notion token
- Added to `.gitignore`
- **NOTE**: Notion token in secrets.env is an OAuth plugin token, NOT an internal integration token. The stdio Notion MCP server was removed from `.mcp.json` — Notion access is now via the OAuth plugin only. See Build Status section.

### 1.4 Add priority tiers + slack_id fields to `config/bonny.json` (fixes L5) — DONE
- Priority 1 (6 channels): #business-plans-dev, #business-plans, #biz-account-squad-sr-leads, #business-leads, #account-details-pod, #proj-relevance-study
- Priority 2 (5 channels): #business-plans-disco-implementation, #temp-business-economics, #business-onboarding-leads, #growing-business-bi-weekly, #receive-chatter
- `slack_id: null` on all — Rohan to fill in for private channels

### 1.5 Create `state/daily-spend.json` (fixes M2) — DONE

### 1.6 Update `config/bonny.example.json` to v2 schema — DONE

### 1.7 Archive stale v1 files — DONE
- `bonny-plan.md` → `Archive/bonny-plan-v1.md`
- `PLAN.md` → `Archive/PLAN-v1.md`
- `scripts/generate-context.sh` → `Archive/generate-context-v1.sh`

### 1.8 Update `.gitignore` — DONE
- Added: `config/secrets.env`, `state/*.json`, `logs/`

---

## Phase 2: Monitor Skills + Scripts — COMPLETE

### 2.1 Slack monitor skill + script — DONE (v3 rewrite 2026-03-26)
- `.claude/commands/skills/slack-monitor-skill.md` (~180 lines) — **Rewritten** with 5-pass priority scan:
  0. **Pass 0: #bonny-inbox** — check for Rohan's replies to Bonny's drafts/questions (feedback loop)
  1. **Pass 1: DMs** — all DMs to Rohan (highest signal)
  2. **Pass 2: @mentions** — all messages mentioning Rohan across all channels
  3. **Pass 3: Threads** — threads Rohan posted in or was mentioned in, with full thread reads
  4. **Pass 4: Channel scan** — all P1 + P2 channels from `config/bonny.json`
- Uses `slack_search_public_and_private` (searches DMs, private channels, group DMs) + `slack_read_channel` + `slack_read_thread`
- `scripts/monitor-slack.sh` — thin runner with budget gate, watermark, skill reference

### 2.2 Confluence monitor skill + script — DONE
- `.claude/commands/skills/confluence-monitor-skill.md` (~70 lines)
- `scripts/monitor-confluence.sh` — thin runner

### 2.3 Meeting monitor skill + script — DONE (v2 rewrite 2026-03-26)
- `.claude/commands/skills/meeting-monitor-skill.md` (~85 lines) — **Rewritten** to use Notion `"Synced to Bonny?"` checkbox for idempotency instead of `state/processed.log`. Apple Calendar MCP references removed; attendees extracted from Notion page properties/transcript. Mark-as-processed step now uses `notion-update-page` to tick the checkbox.
- `scripts/monitor-meetings.sh` — thin runner with Notion checkbox idempotency

---

## Phase 3: Orchestrator + Skills — COMPLETE

### 3.1 Expand `operating_guidelines.md` — DONE
Added: Channel Priority Tiers, Confidence Calibration Examples, Routing Rules Table, Slack Draft Formatting, Deduplication Rules.

### 3.2 Create 5 action skill files — DONE
- `.claude/commands/skills/draft-slack.md`
- `.claude/commands/skills/write-confluence.md`
- `.claude/commands/skills/update-vault.md`
- `.claude/commands/skills/update-tasks.md`
- `.claude/commands/skills/read-calendar.md`

### 3.3 Rewrite `scripts/bonny-run.sh` as orchestrator — DONE
5-phase prompt: load context → read all 3 inboxes → process by priority → health-check monitors → log summary. Supports `--dry-run`.

### 3.4 Create `scripts/generate-context-digest.sh` — DONE
Produces `state/context-digest.md` (~200 lines). Budget: $1. Daily at 6am.

### 3.5 Create `com.bonny.context-digest.plist` — DONE
StartCalendarInterval: daily at 06:00

---

## Phase 4: Self-Improvement Loop — COMPLETE

### 4.1 Create `scripts/self-improvement.sh` — DONE
6-step prompt: read action_log → review Slack drafts vs sent → review vault updates → check stale questions (>3 days) → write review → log activity. Budget: $3.

### 4.2 Create `com.bonny.self-improvement.plist` — DONE
StartCalendarInterval: daily at 07:00

---

## Phase 5: Update Slash Commands — COMPLETE

### 5.1 Update `.claude/commands/monitor-now.md` — DONE
References per-monitor inboxes, skill files, priority tiers.

### 5.2 Update `.claude/commands/process-inbox.md` — DONE
Reads all 3 inbox files, sorts by priority, references skill files for each action type.

---

## Phase 6: Polish & Documentation — COMPLETE

### 6.1 Update `CLAUDE.md` — DONE
Complete rewrite: per-monitor inboxes, skills system tables (3 monitor + 5 action), scheduled agents table (7 agents), updated vault structure, updated workflow phases, updated rules.

### 6.2 Update `scripts/install.sh` — DONE
Added `com.bonny.context-digest` and `com.bonny.self-improvement` to PLISTS array. Updated summary output.

### 6.3 Fix `scripts/cleanup-archives.sh` — DONE
Processes all 3 per-monitor inbox files. Handles `duplicate` status. Uses `sys.argv` instead of inline path interpolation for Python.

### 6.4 Update `building-bonny.md` — DONE
Complete rewrite reflecting v2 architecture, skills, state files, all 7 plists, reduced "What's Left" to actual remaining items.

### 6.5 Fix duplicate `last_updated` in project files — DONE
Removed duplicate frontmatter from all 13 affected files.

---

## Phase 7: BonnyMonitor Menubar App + Budget Override — COMPLETE

*Added: 2026-03-26*

### 7.1 BonnyMonitor — macOS SwiftUI menubar app — DONE
Native menubar app (`BonnyMonitor/`) that visualizes all 7 Bonny agents in real-time:
- **Agent status**: green (scheduled), blue pulsing (running), orange (paused), yellow `$` (budget-paused), red (error)
- **Per-agent details**: click to expand — watermark state, budget per run, recent 5 runs with outcome, error messages
- **Run/Pause controls**: trigger any agent immediately or pause/resume via launchctl load/unload
- **Budget gauge**: shows `$spent/$cap` with color coding. Click to expand breakdown.
- **Budget breakdown**: per-agent cost table with colored proportion bars, run counts, and inline 2x override option
- **Auth status**: per-plugin (Slack, Notion, Atlassian) green/red/orange dots. Click to re-check or trigger re-auth.
- **Skill/log access**: open agent skill files or log directory from detail view
- Built with SwiftUI `MenuBarExtra` + `@Observable` pattern. 30-second auto-refresh timer.
- XcodeGen (`project.yml`) for project generation. `build.sh` for CLI builds.

Files created:
| File | Purpose |
|------|---------|
| `BonnyMonitor/App/BonnyMonitorApp.swift` | @main entry, MenuBarExtra with dynamic icon |
| `BonnyMonitor/App/AppState.swift` | Central @Observable state, 30s refresh timer |
| `BonnyMonitor/Models/AgentDefinition.swift` | Enum defining all 7 agents with filesystem paths |
| `BonnyMonitor/Models/AgentStatus.swift` | Runtime status model with RunState enum |
| `BonnyMonitor/Models/BudgetState.swift` | Budget state with per-agent breakdown + override support |
| `BonnyMonitor/Services/FileSystemService.swift` | Reads budget, watermarks, inbox counts, auth errors |
| `BonnyMonitor/Services/LaunchdService.swift` | Parses launchctl, load/unload agents |
| `BonnyMonitor/Services/LogParser.swift` | Scans logs/ directory, extracts run history |
| `BonnyMonitor/Services/ProcessRunner.swift` | Spawns scripts, auth probes, opens editors |
| `BonnyMonitor/Views/MenuBarView.swift` | Main panel layout with all sections |
| `BonnyMonitor/Views/AgentRowView.swift` | Agent row with status icon and hover controls |
| `BonnyMonitor/Views/AgentDetailView.swift` | Expanded agent detail with runs table |
| `BonnyMonitor/Views/BudgetGaugeView.swift` | Clickable budget gauge |
| `BonnyMonitor/Views/BudgetBreakdownView.swift` | Per-agent spend table with override option |
| `BonnyMonitor/project.yml` | XcodeGen spec: macOS 14.0, Swift 5.9 |
| `BonnyMonitor/build.sh` | Build, copy to build/, relaunch |

### 7.2 Auth-check script — DONE
`scripts/auth-check.sh` — Two modes:
- `--check`: headless Haiku probe ($0.05) that exercises each MCP plugin with a minimal call. Returns OK/FAIL per plugin.
- `--reauth`: opens interactive Terminal session that triggers browser OAuth flow for stale plugins.
- Per-plugin test calls: `slack_search_channels`, `notion-search`, `getVisibleJiraProjects`

### 7.3 Temporary budget override system — DONE
Replaced permanent `config/bonny.json` modification with a temporary day-only override:
- `state/budget-override.json`: `{"date": "YYYY-MM-DD", "cap": 100}` — auto-expires when date is stale
- All 5 shell scripts with budget gates updated to check override file after reading base cap
- BonnyMonitor writes override file (never touches config/bonny.json)
- `config/bonny.json` reverted from $100 back to $50 base cap

### 7.4 #bonny-inbox channel — DONE
- Private Slack channel `#bonny-inbox` for all Bonny drafts and questions
- `draft-slack.md` skill updated to post drafts here with context links
- Slack monitor Pass 0 checks for Rohan's replies (feedback loop)
- `operating_guidelines.md` and `CLAUDE.md` updated

---

## Verification Results (2026-03-22)

| Check | Result |
|-------|--------|
| `bash -n scripts/*.sh` | All 9 scripts pass syntax check |
| `jq . config/bonny.json` | Valid JSON |
| `jq . config/bonny.example.json` | Valid JSON |
| `./scripts/bonny-run.sh --dry-run` | Works — reads all 3 inboxes, checks all 3 watermarks |
| 7 plists present | Confirmed: pm-agent, slack-monitor, confluence-monitor, meeting-monitor, cleanup, context-digest, self-improvement |
| Duplicate last_updated grep | 0 matches — all fixed |

---

## Files Created/Modified Summary

### New files — Phase 7 (18)
| File | Purpose |
|------|---------|
| `BonnyMonitor/App/BonnyMonitorApp.swift` | Menubar app entry point |
| `BonnyMonitor/App/AppState.swift` | Central state with 30s auto-refresh |
| `BonnyMonitor/Models/AgentDefinition.swift` | 7-agent enum with filesystem mappings |
| `BonnyMonitor/Models/AgentStatus.swift` | Runtime status model |
| `BonnyMonitor/Models/BudgetState.swift` | Budget state + per-agent breakdown |
| `BonnyMonitor/Services/FileSystemService.swift` | Budget, watermark, inbox reads |
| `BonnyMonitor/Services/LaunchdService.swift` | launchctl interface |
| `BonnyMonitor/Services/LogParser.swift` | Log file scanner |
| `BonnyMonitor/Services/ProcessRunner.swift` | Script runner + auth probes |
| `BonnyMonitor/Views/MenuBarView.swift` | Main panel layout |
| `BonnyMonitor/Views/AgentRowView.swift` | Agent row with status dots |
| `BonnyMonitor/Views/AgentDetailView.swift` | Expanded agent detail |
| `BonnyMonitor/Views/BudgetGaugeView.swift` | Clickable budget gauge |
| `BonnyMonitor/Views/BudgetBreakdownView.swift` | Per-agent spend breakdown |
| `BonnyMonitor/project.yml` | XcodeGen project spec |
| `BonnyMonitor/build.sh` | CLI build script |
| `scripts/auth-check.sh` | Auth probe + re-auth trigger |
| `BonnyMonitor/Resources/*` | Assets, entitlements, Info.plist |

### New files — Phases 1-6 (20)
| File | Purpose |
|------|---------|
| `Mission_Control/inbox-slack.md` | Slack monitor inbox |
| `Mission_Control/inbox-confluence.md` | Confluence monitor inbox |
| `Mission_Control/inbox-meetings.md` | Meeting monitor inbox |
| `state/slack-monitor-last-run.json` | Slack watermark |
| `state/confluence-monitor-last-run.json` | Confluence watermark |
| `state/meeting-monitor-last-run.json` | Meeting watermark |
| `state/daily-spend.json` | Budget tracking |
| `config/secrets.env` | Notion token (gitignored) |
| `.claude/commands/skills/slack-monitor-skill.md` | Slack monitor instructions |
| `.claude/commands/skills/confluence-monitor-skill.md` | Confluence monitor instructions |
| `.claude/commands/skills/meeting-monitor-skill.md` | Meeting monitor instructions |
| `.claude/commands/skills/draft-slack.md` | Slack drafting instructions |
| `.claude/commands/skills/write-confluence.md` | Confluence writing instructions |
| `.claude/commands/skills/update-vault.md` | Vault update instructions |
| `.claude/commands/skills/update-tasks.md` | Task update instructions |
| `.claude/commands/skills/read-calendar.md` | Calendar reading instructions |
| `scripts/generate-context-digest.sh` | Daily context digest generator |
| `scripts/self-improvement.sh` | Daily self-improvement review |
| `com.bonny.context-digest.plist` | Launchd: daily 6am |
| `com.bonny.self-improvement.plist` | Launchd: daily 7am |

### Rewritten files (9)
`scripts/bonny-run.sh`, `scripts/monitor-slack.sh`, `scripts/monitor-confluence.sh`, `scripts/monitor-meetings.sh`, `operating_guidelines.md`, `.claude/commands/monitor-now.md`, `.claude/commands/process-inbox.md`, `config/bonny.json`, `config/bonny.example.json`

### Updated files (6)
`CLAUDE.md`, `building-bonny.md`, `scripts/install.sh`, `scripts/cleanup-archives.sh`, `.gitignore`, `Mission_Control/inbox.md` (converted to format docs)

### Archived files (3)
`bonny-plan.md` → `Archive/bonny-plan-v1.md`, `PLAN.md` → `Archive/PLAN-v1.md`, `scripts/generate-context.sh` → `Archive/generate-context-v1.sh`

### Frontmatter fixed (13 project files)
Removed duplicate `last_updated` from: relevance-study, monite-integration, account-details-accessibility, multiple-account-details, business-plans-subscriptions, free-plan, business-economics, launchpad-onboarding, acquiring-payfac, invoicing-2026, accounting-integrations, file-exports, nbb-qa-mua-experience

---

## Decisions (confirmed with Rohan)

- **#bonny-inbox channel** (2026-03-26): Private Slack channel `#bonny-inbox` (`C0ANXUENY13`) replaces DMs to Rohan for all Bonny drafts and questions. Rohan reviews drafts and replies in-thread. Slack monitor Pass 0 picks up Rohan's replies and routes them back through the inbox pipeline. Local backups still saved to `state/slack-drafts/`.
- **Budget cap**: $50/day across all agents
- **Slack channel IDs**: Adding `slack_id` fields to bonny.json — Rohan will fill in IDs for private channels
- **Notion auth**: Using OAuth plugin (not internal integration token). Stdio MCP server removed from `.mcp.json`.
- **Meeting idempotency via Notion checkbox** (2026-03-26): `"Synced to Bonny?"` checkbox property on Notion Meeting Notes DB replaces `state/processed.log`. Meeting monitor skill updated to filter for unchecked pages and tick the checkbox after processing. All 18 historical meetings also ticked.

---

## Deployment & Runtime Status

*Updated: 2026-03-26*

### MCP Connection Status
| Server | Status | Interactive | Headless (`--print`) | Notes |
|--------|--------|-------------|----------------------|-------|
| **Atlassian** (HTTP remote) | Working | Yes | Yes | OAuth via `https://mcp.atlassian.com/v1/mcp`. Used by Confluence monitor. |
| **Notion** (plugin) | Working | Yes | No | OAuth via `/plugin notion`. 4 meetings successfully processed interactively. Headless gets 401 — OAuth plugins not supported in `claude --print`. |
| **Slack** (plugin) | Working | Yes | Intermittent | OAuth via `/plugin slack`. Reconnected 2026-03-26. Full tool suite available: `slack_read_channel`, `slack_search_public_and_private`, `slack_read_thread`, `slack_search_users`. Headless runs succeeded Mar 23–26 but overnight gaps observed — plugin auth may expire. |
| **Apple Calendar** (stdio) | Removed | N/A | N/A | `mcp-ical` package never existed on PyPI. Removed from `.mcp.json`. Calendar access now via Notion meeting notes (`notion-query-meeting-notes`). |
| **Desktop** (stdio) | Working | Yes | N/A | `npx native-devtools-mcp` |

### Launchd Agents — Installed & Registered (2026-03-22, schedules updated 2026-03-26)
All 7 plists installed via `scripts/install.sh` to `~/Library/LaunchAgents/`. All agents run **Mon-Fri only, business hours (9am-6pm)**. Uses `StartCalendarInterval` with explicit weekday+hour entries for deterministic scheduling.

| Agent | Plist | Schedule | Headless Status |
|-------|-------|----------|-----------------|
| Slack Monitor | `com.bonny.slack-monitor` | Hourly at :00, Mon-Fri 9-17 | **Working intermittently.** Successful runs Mar 23–26 (all 11 channels scanned). Overnight gaps when plugin auth expires. Skill rewritten with 5-pass priority scan (bonny-inbox → DMs → mentions → threads → channels). |
| Confluence Monitor | `com.bonny.confluence-monitor` | 2-hourly at :00, Mon-Fri 10-18 | **Working end-to-end.** Scanned 14 pages, found real changes, wrote inbox entries, orchestrator processed them into vault. |
| Meeting Monitor | `com.bonny.meeting-monitor` | 2-hourly at :00, Mon-Fri 10-18 | **Working.** Skill rewritten to use Notion `"Synced to Bonny?"` checkbox for idempotency (replaces `state/processed.log`). Apple Calendar MCP removed; attendees from Notion. 18 meetings processed Mar 23–26. |
| Orchestrator | `com.bonny.pm-agent` | 2-hourly at :20, Mon-Fri 10-18 | Working. 20-min offset after monitors ensures inbox is populated. Shell-level pre-check skips Claude entirely if inboxes empty. Budget scales by item count ($2/$3/$5). |
| Context Digest | `com.bonny.context-digest` | Daily 6am | Untested. Should work — only reads local files. |
| Self-Improvement | `com.bonny.self-improvement` | Mon-Fri at 5:00 PM | Untested. Should work — only reads local files. |
| Cleanup | `com.bonny.cleanup` | Mon-Fri at 5:30 PM | Untested. Should work — only reads/writes local files. |

### Key Limitation: OAuth Plugins in `--print` Mode
OAuth plugin auth in `claude --print` (headless) is **intermittent** — it works after a fresh interactive re-auth but may expire overnight. HTTP remote MCP servers (Atlassian) always work. Current status:
- **Confluence monitor**: Fully automated, always works (Atlassian HTTP remote MCP)
- **Slack monitor**: Works after re-auth, may fail overnight. 5-pass skill rewrite (2026-03-26) maximises value from each successful run. Pass 0 checks #bonny-inbox for Rohan's replies.
- **Meeting monitor**: Works after re-auth, may fail overnight. Same intermittent pattern as Slack.

### First Real-World Run Results (2026-03-22–23)
| Monitor | Items Found | Inbox Entries Written |
|---------|-------------|---------------------|
| Confluence (automated) | 2 page changes (AIR 1-Pager, BizOn 1-Pager) | 3 entries (1 duplicate) |
| Meetings (interactive) | 4 meetings from past week | 4 entries |
| Slack (automated) | 0 (11 channels scanned, no new messages in 30min windows) | 2 entries (historical, from prior session) |

### Orchestrator Processing Results (2026-03-22–23)
| Action Type | Count | Details |
|-------------|-------|---------|
| Vault updates | 8 | chapter_hiring, business-plans-subscriptions (x2), air_kpis, air_people, accounting-integrations, bizon_projects_charter, launchpad-onboarding, bam_projects_charter, bizon_people, ast_people, bam_people |
| Slack drafts | 2 | Relevance study cost alignment reminder, Christo meeting narrative reminder |
| Duplicates skipped | 1 | AIR 1-Pager cosmetic edit |
| Questions logged | 2 | Confluence monitor never-run (now resolved), Margaret's BAM work stream doc |

### 4-Pass Slack Monitor Test Results (2026-03-26, 24hr window)
| Pass | Items Found |
|------|-------------|
| Pass 1: DMs | 4 (Steve/Pragya offer, Divya/MUA data, Amin/BAX dashboard, Dan/unavailable 16th, Hollie/Free Plan) |
| Pass 2: @mentions | 1 (Harsh feedback in #biz-account-squad-sr-leads) |
| Pass 3: Threads | 0 new (already covered by Pass 1-2) |
| Pass 4: Channel scan | 2 (Kristo meeting reschedule in #business-plans-dev, Kim/Launchpad design in #biz-account-squad-sr-leads) |
| **Total actionable** | **9** (8 pending + 1 FYI auto-processed) |

### Orchestrator Processing Results (2026-03-26 — Slack monitor batch)
| Action Type | Count | Details |
|-------------|-------|---------|
| Vault updates | 6 | chapter_hiring (Pragya offer approved), business-plans-subscriptions (Kristo meeting rescheduled to Fri 2pm), bax_kpis (MUA V3 +28% uplift), bax_projects_charter (dashboard components), bas_squad_info (capacity/risks), launchpad-onboarding (design cadence) |
| Slack drafts | 4 | Pragya offer reminder, Kristo meeting reschedule, BAX dashboard Amin call prep, Dan replacement 16th |
| DMs sent to Rohan | 4 | All 4 drafts above sent as actual Slack DMs |
| Skipped | 2 | Hollie/Free Plan reminder (Rohan aware), sCCY CS guidance (FYI only) |

### Meeting Monitor Batch Processing (2026-03-26 — 5 unprocessed meetings from Mar 25)
| Meeting | Type(s) | Inbox Entries |
|---------|---------|---------------|
| Fraud Domain Alignment & Product Lead Hiring | DECISION, ACTION_ITEM, RISK | 3 entries (£500 limit, AI fraud prototype, org friction, hiring reset) |
| MUA Strategy Learning Plan Questions | DECISION, ACTION_ITEM | 2 entries (learning plan framework, pseudo-MUA/delegated owner pattern) |
| Mel/Rohan — Plans Tiering & MUA Paywall | DECISION, ACTION_ITEM, STATUS_CHANGE | 3 entries (two-plan structure, Revolut competitive data, design actions) |
| Risk Alignment & Onboarding Blockers | DECISION, ACTION_ITEM | 2 entries (VAMP compliance, onboarding criteria 2-week deadline) |
| Bernardo Offer & Crystal Subscription Strategy Prep | DECISION, ACTION_ITEM | 2 entries (MUA removed from paywall proposal per Nilan, Kristo meeting prep) |
| **Total** | | **13 new inbox entries** |

All 5 meetings + 13 previously-processed meetings had `"Synced to Bonny?"` checkbox ticked in Notion.

### What Needs Doing Next
1. **Fill Slack channel IDs** — `config/bonny.json` has `slack_id: null` for all 11 channels. The Slack monitor can find public channels by name but private channels are hit-or-miss. Filling in IDs ensures consistent access.
2. **Monitor plugin auth stability** — Slack and Notion plugins work after interactive re-auth but may expire overnight. Auth-check script (`scripts/auth-check.sh`) and BonnyMonitor app provide visibility + re-auth triggers.
3. **BonnyMonitor app signing** — Currently builds unsigned. For distribution, consider Developer ID signing or notarization.

### What's Fully Working
- All 10 shell scripts pass `bash -n` syntax check (9 original + auth-check.sh)
- Both JSON configs valid
- Orchestrator processes all 3 inboxes, routes by priority, updates vault, drafts Slack, logs actions
- Confluence monitor runs automated every 2 hours, finds real changes, writes inbox entries
- All 8 skill files in place and tested
- Per-monitor inboxes with structured entries
- Budget gate logic in all scripts ($50/day cap) with temporary override support
- Vault has 55 business files, 101 people, 26 projects — all wikilinks valid
- `/monitor-now` works interactively for all 3 monitors (Slack reconnected 2026-03-26)
- `/process-inbox` works — tested with 9 real inbox items across 3 inboxes
- Action log, questions log, and Slack drafts all functioning
- `#bonny-inbox` channel — Bonny posts drafts + questions here, replies picked up as feedback loop
- BonnyMonitor menubar app — real-time agent status, budget breakdown, auth checks, run/pause controls
- Auth-check script — headless probes + interactive re-auth for OAuth plugins
- Temporary budget override — day-only 2x via `state/budget-override.json`, auto-expires

### `.mcp.json` Current State
```json
{
  "mcpServers": {
    "desktop": {
      "command": "npx",
      "args": ["-y", "native-devtools-mcp"]
    },
    "atlassian": {
      "type": "http",
      "url": "https://mcp.atlassian.com/v1/mcp"
    }
  }
}
```
Notion is NOT in `.mcp.json` — it's accessed via the OAuth plugin. Do NOT re-add it unless switching back to an internal integration token.

### `config/secrets.env` Note
Contains `NOTION_TOKEN` but this is an OAuth plugin token, not a valid internal integration token. The monitor scripts source this file, but since Notion is now via plugin, this token is unused by the stdio server. If headless monitors need Notion access, Rohan will need to create a proper internal integration at notion.so/my-integrations and paste that token here instead.
