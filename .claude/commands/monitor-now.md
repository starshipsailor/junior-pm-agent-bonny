Run all three Bonny monitors (Slack, Confluence, Meetings) right now in a single pass.

## Steps

1. Load context: read `state/context-digest.md` (if it exists), then `operating_guidelines.md`, `config/bonny.json`

### Slack Monitor
2. Read and execute `.claude/commands/skills/slack-monitor-skill.md`
3. Use `config/bonny.json` → `slack_channels` for the channel list with priority tiers
4. For Priority 1 channels: read ALL recent messages (last 2 hours)
5. For Priority 2 channels: only messages where Rohan is mentioned
6. Check DMs to Rohan
7. Write actionable items to `Mission_Control/inbox-slack.md`

### Confluence Monitor
8. Read and execute `.claude/commands/skills/confluence-monitor-skill.md`
9. Use `config/bonny.json` → `confluence_watch_pages` for pages to check
10. For each page, use Atlassian MCP to check if recently modified
11. For updated pages, read project context before summarizing
12. Write actionable items to `Mission_Control/inbox-confluence.md`

### Meeting Monitor
13. Read and execute `.claude/commands/skills/meeting-monitor-skill.md`
14. Query Notion meeting notes database (`config/bonny.json` → `notion_meeting_notes_db`)
15. Find meetings from the last 24 hours not yet in `state/processed.log`
16. Match attendees via Apple Calendar MCP + `People/Global_people_index.md`
17. Extract: summary, decisions, action items, follow-ups, risks
18. Write structured entries to `Mission_Control/inbox-meetings.md`
19. Append processed page IDs to `state/processed.log`

### Wrap Up
20. Log all activity to `Mission_Control/agent_activity_log.md` with timestamp and summary
21. Print a summary: channels scanned, pages checked, meetings processed, total inbox items added across all 3 inboxes
