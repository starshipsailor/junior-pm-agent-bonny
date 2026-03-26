# Skill: Update Task List

## When to Use
- Action item identified in meeting or Slack
- Task completed (mark as done)
- Task blocked (update status)
- Deadline changed

## Task List Location

Tasks are tracked in `templates/task-list.md` format within relevant project files. Global tasks go in the project file's action items section.

## Process

### Adding a New Task
1. Identify the owner, deadline, and source from the inbox entry
2. Find the correct location:
   - If project-specific → append to the project file's action items section
   - If person-specific → append to the person file's 1:1 Notes section
3. Use Obsidian task format:

```
- [ ] [Task description] #task @[[Owner_Name_Team]] 📅 YYYY-MM-DD
  - Source: [Slack/#channel or Meeting:Title or Confluence:Page]
```

### Completing a Task
1. Find the task in the relevant file
2. Change `- [ ]` to `- [x]`
3. Add completion date: `✅ YYYY-MM-DD`

### Marking a Task as Blocked
1. Find the task
2. Add `🚫 BLOCKED:` with reason

## Logging

After updating, append to `Outputs_and_Self_Improvement/action_log.md`:

```
| TASK-YYYYMMDD-HHMM | YYYY-MM-DD HH:MM | task-update | [file path] | [task summary] | | | |
```

## Rules

- Only APPEND new tasks. Never remove or modify existing task text.
- Always include the source (where the task was identified).
- Always include an owner and deadline if available.
- If no deadline is mentioned, note "no deadline specified".
