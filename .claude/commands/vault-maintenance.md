Run a vault consistency check and fix any issues found.

## Steps

### 1. Wikilink Integrity
- Scan all `.md` files for `[[wikilinks]]`
- For each wikilink, verify the target file exists in the vault
- Report any broken links with: source file, broken link, suggested fix
- Fix broken links if the correct target is obvious (e.g. filename typo, moved file)

### 2. Frontmatter Validation
- Check all project files have required YAML frontmatter: `type`, `status`, `priority`, `people`, `slack_channels`, `last_updated`
- Check all people files have: `name`, `role`, `team`, `slack_handle`
- Report any files with missing required fields

### 3. Cross-Reference Consistency
- Verify people referenced in project files (`[[Firstname_Lastname_Team]]`) exist in `People/individual_people/`
- Verify people listed in project files are also listed in their team's `*_people.md`
- Verify projects listed in `*_projects_charter.md` files have corresponding project files in the team's `*_projects/` directory
- Report orphaned files (project files not referenced in any charter)

### 4. Index Freshness
- Check `People/Global_people_index.md` includes all people from `People/individual_people/`
- Check each team's `*_projects_charter.md` lists all projects in its `*_projects/` folder
- Report any missing entries

### 5. Stale Content Detection
- Flag any files where `last_updated` is more than 30 days old
- Flag any projects with `status: in-progress` but `last_updated` older than 14 days

### 6. Report & Fix
- Print a summary table: checks run, issues found, issues auto-fixed
- For issues that can't be auto-fixed, write them to `Outputs_and_Self_Improvement/questions_for_rohan.md`
- Log the maintenance run to `Outputs_and_Self_Improvement/action_log.md`
