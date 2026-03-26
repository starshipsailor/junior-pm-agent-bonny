# Skill: Draft Slack Message

## When to Use
- Action item with deadline <3 days
- Decision affecting absent stakeholders
- Blocker needing escalation
- Follow-up promised but not done
- Acknowledgment of completed work
- Self-improvement loop reminders to Rohan
- Questions for Rohan (low-confidence items)

## Process

1. Read the inbox item that triggered this action
2. Identify the recipient(s) and relevant context:
   - If it's a reminder for Rohan → post to #bonny-inbox
   - If it's a follow-up to someone → post to #bonny-inbox with recipient noted
   - If it's an acknowledgment → post to #bonny-inbox with channel context
   - If it's a question for Rohan → post to #bonny-inbox with [QUESTION] prefix
3. Read the relevant person file from `People/individual_people/` for context on the recipient
4. Draft the message following the tone rules in `operating_guidelines.md`

## Delivery: Post to #bonny-inbox

**Channel ID**: `C0ANXUENY13` (private channel `#bonny-inbox`)

Post all drafts and questions directly to `#bonny-inbox` using `slack_send_message`. This replaces the old local file drafts in `state/slack-drafts/`.

### Message Format — Draft

```
*Draft — [Topic]*
*To*: @firstname.lastname or #channel-name
*Priority*: High / Medium / Low
*Context*: [link to relevant Slack message/thread if available]

---

[Draft message body — what Rohan would send]

---
_Source: [inbox file + timestamp] | Task: SLACK-YYYYMMDD-HHMM_
```

### Message Format — Question for Rohan

```
*Question — [Topic]*
*Priority*: High / Medium / Low

[Question text — what Bonny needs Rohan's input on]

*Context*: [why Bonny is asking, what triggered it]

---
_Source: [inbox file + timestamp] | Task: QUESTION-YYYYMMDD-HHMM_
```

## Also Save Locally

After posting to #bonny-inbox, still save the draft to `state/slack-drafts/YYYY-MM-DD-recipient-topic.md` as a backup record. Use this format:

```
---
to: "@firstname.lastname" or "#channel-name"
re: [Topic - brief description]
source_inbox: inbox-slack.md or inbox-confluence.md or inbox-meetings.md
source_timestamp: [timestamp from the inbox entry]
drafted: YYYY-MM-DD HH:MM
status: posted-to-bonny-inbox
task_id: [auto-generated: SLACK-YYYYMMDD-HHMM]
bonny_inbox_link: [message link from slack_send_message response]
---

[Message body]
```

## Formatting Rules

- First line: greeting + purpose
- Body: 2-3 sentences max, specific about what's needed and by when
- Closing: clear ask or acknowledgment
- Use first names, not formal titles
- Use specific dates ("by Wednesday March 26"), not "soon"
- One exclamation mark max per message. Zero is fine.
- Internal Wise tone: direct, friendly, no corporate fluff

## Logging

After posting, append to `Outputs_and_Self_Improvement/action_log.md`:

```
| SLACK-YYYYMMDD-HHMM | YYYY-MM-DD HH:MM | slack-draft | #bonny-inbox → @recipient | [first 80 chars of draft] | | | |
```

## Rules

- Post drafts and questions to `#bonny-inbox` (C0ANXUENY13). Rohan reviews there.
- Also save a local backup to `state/slack-drafts/`.
- If unsure about tone or content, post as a question (❓ prefix) instead of a draft.
- Each draft/question gets a unique task_id for self-improvement tracking.
