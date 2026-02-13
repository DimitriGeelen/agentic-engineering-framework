# Session Capture Agent

> Systematically scans a session for uncaptured work items, learnings, and decisions.

## Purpose

Ensure nothing discussed in a session is lost. This agent enforces P-007 (Systematic Session Capture).

## When to Use

**MANDATORY before:**
- Ending a work session
- Switching to a different task/topic
- Committing a significant milestone
- Any context transition

## What to Scan For

| Category | Look For | Capture As |
|----------|----------|------------|
| **Work Items** | "We should...", "Need to...", "TODO", future tense actions | Tasks |
| **Decisions** | "Let's use...", "We decided...", choices made | Task updates or ADRs |
| **Learnings** | "We learned...", pivots, failures, surprises | Practices or task updates |
| **Questions** | "What if...", "How do we...", unresolved issues | Tasks or Vision doc |
| **Gaps** | Things referenced but don't exist | Tasks |

## Checklist

Run through this before ending a session:

```
[ ] Scan conversation for "should", "need to", "TODO", "will"
[ ] Check: did we discuss work that has no task?
[ ] Check: did we make decisions not recorded anywhere?
[ ] Check: did we learn something that should be a practice?
[ ] Check: did we raise questions that remain open?
[ ] Check: do referenced files/structures actually exist?
[ ] Create tasks for all identified work
[ ] Update existing tasks with new context
[ ] Capture learnings in 015-Practices.md or task Updates
```

## Integration

**For AI Agents:**
Add to your provider integration file (CLAUDE.md, .cursorrules, etc.):
> Before ending a session, invoke the session-capture checklist. Do not close without confirming all discussed work is captured as tasks.

**For Humans:**
Run `./agents/session-capture/capture.sh` or mentally run the checklist.

## Output

A report listing:
1. Tasks created
2. Tasks updated
3. Practices captured
4. Questions logged
5. Gaps identified

## Why This Exists

**Origin:** Meta-failure on 2026-02-13

We discussed 10+ work items in a session but only created 3 tasks. The rest would have been lost if not for a later review. This agent exists to prevent that pattern.

**The cost of not using this:**
- Lost context between sessions
- Work discussed but never done
- Learnings never captured
- Repeated mistakes
- Incomplete task boards

## Anti-pattern This Prevents

> "We talked about a lot of stuff today. I'll remember the important parts."

You won't. Capture it now.
