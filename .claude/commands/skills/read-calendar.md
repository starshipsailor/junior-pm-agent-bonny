# Skill: Read Calendar (via Notion Meeting Notes)

## When to Use
- Need to identify meeting attendees
- Need to understand Rohan's recent/upcoming meetings for context
- Checking what meetings happened on a given day
- Meeting prep — pulling context for an upcoming meeting

## Source

Use the Notion plugin's `notion-query-meeting-notes` tool. This queries Rohan's meeting notes database, which syncs from his Google Calendar (rohan.vadgaonkar@wise.com).

## Process

### Finding Meetings for a Date Range
```
notion-query-meeting-notes(
  filter={
    "operator": "and",
    "filters": [{
      "property": "created_time",
      "filter": {
        "operator": "date_is_within",
        "value": { "type": "relative", "value": "the_past_week" }
      }
    }]
  }
)
```

### Finding a Specific Meeting by Title
```
notion-query-meeting-notes(
  filter={
    "operator": "and",
    "filters": [{
      "property": "title",
      "filter": {
        "operator": "string_contains",
        "value": { "type": "exact", "value": "search term" }
      }
    }]
  }
)
```

### Finding Meetings with a Specific Person
1. First use `notion-search` with `query_type: "user"` to find their Notion user ID
2. Then filter by attendee:
```
notion-query-meeting-notes(
  filter={
    "operator": "and",
    "filters": [{
      "property": "notion://meeting_notes/attendees",
      "filter": {
        "operator": "person_contains",
        "value": [{ "type": "exact", "value": { "table": "notion_user", "id": "USER_ID" } }]
      }
    }]
  }
)
```

### Reading Full Meeting Content
Use `notion-fetch` with the meeting page ID from the query results to get full transcript and notes.

## What's Available
- Meeting title, date/time, attendees
- Full meeting transcript (via Notion AI)
- Meeting notes and action items
- Created/edited timestamps

## What's NOT Available
- Real-time calendar view (today's full schedule)
- Free/busy slots
- Non-meeting calendar events (focus time, OOO, etc.)
- Future meetings without transcripts (only shows up once the meeting happens and gets a transcript)

## Output

Calendar data is used as context for other actions — it doesn't produce its own inbox entries or vault updates. Feed the information into the relevant monitor or orchestrator action.

## Rules

- Always cross-reference meeting attendees with `People/Global_people_index.md` for wikilinks.
- If an attendee isn't in the people index, note them by name without a wikilink.
- Calendar data supplements other sources — don't create inbox entries from calendar events alone.
- Notion meeting notes only appear after a meeting happens (with transcript). For future meeting prep, check Slack/Confluence for agenda or context instead.
