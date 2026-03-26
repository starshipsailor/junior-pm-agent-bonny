# Skill: Update Vault

## When to Use
- Project status change (started, blocked, completed, on-hold)
- Person role change (new hire, departure, team move)
- New KPI data (metrics updated, targets revised)
- New decision made that should be recorded
- Team structure change

## Process

### For Project Updates
1. Identify the project from the inbox entry's `Project` field
2. Navigate to the correct file: `Business_Chapter/{Squad}/{Team}/{prefix}_projects/{project-file}.md`
3. Read the current file to understand existing content
4. Append the new information under the appropriate section (Status, Key Deliverables, Current Status, etc.)
5. Update `last_updated` in YAML frontmatter to today's date
6. If the project status changed, also update the team's `*_projects_charter.md` table

### For People Updates
1. Identify the person from the inbox entry's `People` field
2. Navigate to `People/individual_people/{Firstname_Lastname_Team}.md`
3. Read the current file
4. Append new context to the "Context Log" section with a date stamp:
   ```
   ### YYYY-MM-DD
   [New context learned from source]
   ```
5. Update `last_updated` in YAML frontmatter
6. If the person's role or team changed, also update:
   - `People/Global_people_index.md` (the table row)
   - The relevant team's `*_people.md` file

### For KPI Updates
1. Identify the team from the inbox entry
2. Navigate to `Business_Chapter/{Squad}/{Team}/{prefix}_kpis.md`
3. Read the current file
4. Update the relevant metric values
5. Update `last_updated` in YAML frontmatter

## Link Conventions

Always use proper wikilinks:
- People: `[[Firstname_Lastname_Team]]`
- Projects: `[[project-filename]]` (e.g., `[[accounting-integrations]]`)
- Team docs: `[[teamprefix_kpis]]`, `[[teamprefix_people]]`, `[[teamprefix_projects_charter]]`
- Squad/chapter: `[[bas_squad_info]]`, `[[chapter_strategy]]`

## Logging

After updating, append to `Outputs_and_Self_Improvement/action_log.md`:

```
| VAULT-YYYYMMDD-HHMM | YYYY-MM-DD HH:MM | vault-update | path/to/file.md | [what changed] | | | |
```

## Rules

- Always read the file before editing — never write blindly.
- Only append to task lists and context logs — never remove or modify existing entries.
- Update `last_updated` frontmatter on every edit.
- Maintain wikilink consistency — use the conventions above.
- If you're unsure which file to update, log to `questions_for_rohan.md`.
