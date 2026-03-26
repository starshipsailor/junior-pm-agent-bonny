Process all pending items across all inbox files using the operating guidelines.

## Steps

1. Load context: read `state/context-digest.md` (if it exists), then `operating_guidelines.md`, `People/Global_people_index.md`
2. Read ALL inbox files and identify items with `status: pending`:
   - `Mission_Control/inbox-slack.md`
   - `Mission_Control/inbox-confluence.md`
   - `Mission_Control/inbox-meetings.md`
3. Sort pending items by priority: BLOCKER > ACTION_ITEM (Rohan) > ACTION_ITEM (others) > DECISION > STATUS_CHANGE > PERSONNEL > RISK

4. For each pending item, in priority order:

### Classify & Act
   a. Read the related project file and team context from the vault
   b. Check if the information is already captured in the vault (deduplication)
   c. Apply the routing rules from `operating_guidelines.md` to determine the action:
      - **Update vault**: Read `.claude/commands/skills/update-vault.md`, then edit the relevant project/people/KPI file. Update `last_updated` frontmatter.
      - **Draft Slack**: Read `.claude/commands/skills/draft-slack.md`, then write a draft to `state/slack-drafts/`. NEVER send directly.
      - **Write Confluence**: Read `.claude/commands/skills/write-confluence.md`, then draft content for Rohan's review.
      - **Update tasks**: Read `.claude/commands/skills/update-tasks.md`, then append to relevant task list.
      - **Do nothing**: If FYI-only, already captured, or low confidence — log to `Outputs_and_Self_Improvement/questions_for_rohan.md`.

### Mark Processed
   d. Update the item's status in its inbox file from `pending` to `processed` (or `duplicate`)
   e. Log the action taken to `Outputs_and_Self_Improvement/action_log.md` with a unique task ID

5. After processing all items, print a summary: items processed, actions taken (vault updates, drafts written, questions logged), items skipped as duplicates
6. If any items were low-confidence, remind Rohan to check `Outputs_and_Self_Improvement/questions_for_rohan.md`
