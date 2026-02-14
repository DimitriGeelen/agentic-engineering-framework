# /resume - Context Recovery for Agentic Engineering Framework

When the user says `/resume`, "pick up", or "continue", execute this workflow.

## Step 1: Gather State

Run these in parallel:

1. Read `.context/handovers/LATEST.md`
2. Run `git status --short` and `git log --oneline -5`
3. List `.tasks/active/` and extract task IDs, names, and statuses from frontmatter
4. Check tool counter: `cat .context/working/.tool-counter`
5. Check web server: `curl -sf http://localhost:3000/ > /dev/null && echo "running" || echo "stopped"`

## Step 2: Summarize

Present this format (fill from gathered data):

```
## Context Restored

**Last Handover:** {session_id} ({timestamp})
**Last Commit:** {hash} - {message}
**Branch:** {branch}

### Where We Are
{paste the "Where We Are" section from LATEST.md}

### Active Tasks
- {T-XXX}: {name} ({status})

### Current State
- Git: {clean/N uncommitted files}
- Web UI: {running on :3000 / stopped}
- Tool counter: {N} (P-009)

### Suggested Action
{paste from LATEST.md "Suggested First Action" section}
```

## Step 3: Offer Next Steps

List the logical next actions as plain text (numbered). Derive from:
- The handover's "Suggested First Action"
- Any tasks with status `started-work`
- Uncommitted changes that need attention

Then ask: "What would you like to work on?"

## Rules

- Do NOT use AskUserQuestion (blocked in dontAsk mode) — use plain text
- Keep output concise — no "Why this matters" commentary
- If LATEST.md has unfilled `[TODO]` sections, warn about stale handover
- If tool counter > 0 at session start, the PostToolUse hook is working
