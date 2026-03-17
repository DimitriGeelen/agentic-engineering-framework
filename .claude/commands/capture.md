# /capture - Emergency Conversation Capture

When the user types `/capture`, execute this workflow to save the current
conversation to disk before it is lost.

## Step 1: Check active task

Read `.context/working/focus.yaml` to get `current_task`.

If no active task or `current_task` is empty:
- Print: "No active task. Run `fw work-on 'topic'` first to create one, then retry /capture."
- Stop here.

## Step 2: Extract conversation from transcript

Run:
```
python3 agents/capture/read-transcript.py
```

This reads the live JSONL transcript and returns JSON with:
- `turns`: array of `{role, content, timestamp}` objects
- `captured_turns`: how many turns were captured
- `capture_mode`: how the boundary was detected

If the script exits non-zero or returns empty turns, print the warning from
stderr and stop.

## Step 3: Write the artifact

Generate the artifact path:
```
docs/reports/{current_task}-capture-{YYYY-MM-DD-HH}.md
```

Write the file with this structure:

```markdown
# {current_task}: Conversation Capture — {YYYY-MM-DD HH:MM}

> Captured via /capture | Turns: {captured_turns} | Mode: {capture_mode}
> Task: {current_task}

## Topic / Problem Statement

{Summarise in 2-3 sentences what this conversation is about, based on the turns.}

## Key Insights

{List the most important findings or conclusions reached, as bullet points.
Extract from the conversation content — don't hallucinate.}

## Options Explored

{If alternatives were discussed, list them with brief notes on each.
Skip this section if no options were compared.}

## Decisions Made

{List any explicit decisions or directions agreed on.
Skip if no decisions were made.}

## Open Questions

{List anything that was raised but not resolved.}

## Conversation Log

{For each turn in the turns array, format as:}

**Human** _{timestamp}_
{content}

---

**Agent** _{timestamp}_
{content}

---
```

## Step 4: Commit

Run:
```
fw git commit -m "{current_task}: /capture — conversation artifact"
```

## Step 5: Report back

Print:
```
Saved: docs/reports/{filename}
Committed: {commit hash}
Turns captured: {N} ({capture_mode})

Content is now safe on disk.
```

## Rules

- Do NOT fabricate content in Key Insights, Options, or Decisions — derive only from turns
- If the transcript reader returns a format canary warning, include it in the output
- The Conversation Log section is verbatim — do not edit or summarise the turns there
- If `docs/reports/` does not exist, create it
