# /review - Show all tasks pending human review

When the user says `/review`, execute this workflow.

## Step 1: Find tasks with pending Human ACs

Run: `bin/fw task verify`

This lists all tasks with unchecked Human ACs.

## Step 2: Show review for each task

For each task listed in Step 1, run:

```
bin/fw task review T-XXX
```

This outputs the Watchtower URL, QR code, research artifacts, and Human AC count.

## Step 3: Summarize

Present a numbered list of tasks awaiting human review with their URLs.
If no tasks have pending Human ACs, say so.

## Rules

- Do NOT use AskUserQuestion — present results directly
- Run `fw task review` for EACH pending task, not just the first one
- If there are more than 5 pending tasks, show the first 5 and note how many remain
