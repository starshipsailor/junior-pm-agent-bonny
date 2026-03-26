# Skill: Write Confluence Page

## When to Use
- Significant product decision affecting multiple teams
- Major review meeting outcomes (steering committee, MBR)
- New project brief or decision record

## Process

1. Read the inbox item that triggered this action
2. Identify the target Confluence space and parent page:
   - Check `config/bonny.json` → `confluence_watch_pages` for existing page mappings
   - If updating an existing page, use `getConfluencePage` to read current content first
3. Draft the content following Wise's internal documentation style

## For New Pages

Use the Atlassian MCP `createConfluencePage` with:
- **Space**: Match to the relevant team's space from confluence_watch_pages
- **Title**: Clear, descriptive, include date if it's a decision record
- **Content**: Structured with headings, decision rationale, owners, next steps

## For Updating Existing Pages

Use the Atlassian MCP `updateConfluencePage`:
- Read current content first to understand structure
- Append new information in the appropriate section
- Don't overwrite existing content — add to it

## Draft Review

Before creating/updating, write the draft to `state/confluence-drafts/YYYY-MM-DD-topic.md`:

```
---
action: create | update
space: SPACE_KEY
page_id: PAGE_ID (for updates)
title: Page Title
source_inbox: [which inbox triggered this]
drafted: YYYY-MM-DD HH:MM
status: pending-review
task_id: CONF-YYYYMMDD-HHMM
---

[Page content in Confluence wiki format]
```

Present the draft to Rohan for review before executing the MCP call.

## Logging

After writing the draft, append to `Outputs_and_Self_Improvement/action_log.md`:

```
| CONF-YYYYMMDD-HHMM | YYYY-MM-DD HH:MM | confluence-draft | Space/PageTitle | [summary] | | | |
```

## Rules

- NEVER create or update a Confluence page without Rohan's review.
- Always read the existing page content before updating.
- Keep Confluence pages factual and structured — not narrative.
