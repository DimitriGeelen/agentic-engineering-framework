# Handover Agent

> Generates context transfer documents to enable seamless session continuity.

## Purpose

The handover agent is **the bridge between sessions**. While the task system captures *what* needs to be done and session capture ensures *nothing is lost*, handover ensures **continuity of understanding**.

**Key insight:** Handover is forward-looking synthesis, not backward-looking capture. It answers "what does the next session need?" rather than "what did this session do?"

## When to Use

| Trigger | Behavior |
|---------|----------|
| **End of session** (MANDATORY) | Generate full handover document |
| **On demand** | "Generate handover for current state" |
| **Before major context switch** | Even mid-session if switching focus |

## Prerequisites

1. Run session capture first (`agents/session-capture/AGENT.md`)
2. Ensure all changes are committed or documented
3. All discussed work should have tasks

## The Handover Synthesis Process

### Step 1: Gather State (Automatic)

The script gathers:
- Active task list and statuses
- Recent commits
- Uncommitted changes
- Current timestamp

### Step 2: Synthesize Context (Intelligent)

Claude Code synthesizes:
- Current state summary (where are we?)
- Work in progress with next steps
- Decisions made and alternatives rejected
- Things tried that failed
- Open questions/blockers
- Gotchas for next session
- Suggested first action

### Step 3: Write Handover (Automatic)

- Creates `.context/handovers/S-[timestamp].md`
- Updates `.context/handovers/LATEST.md`

## Handover Document Structure

```markdown
---
session_id: S-YYYY-MMDD-HHMM
timestamp: [ISO 8601]
predecessor: [previous session ID]
tasks_active: [list]
tasks_touched: [list]
tasks_completed: [list]
owner: [who generated]
---

# Session Handover: [session_id]

## Where We Are
[2-3 sentences: Current state, immediate situation]

## Work in Progress

### T-XXX: [Task Name]
- **Status:** [status]
- **Last action:** [what was just done]
- **Next step:** [what should happen next]
- **Blockers:** [any blockers]
- **Insight:** [key understanding gained]

[Repeat for each active task touched this session]

## Decisions Made This Session

1. **[Decision]**
   - Why: [rationale]
   - Alternatives rejected: [what else was considered]

## Things Tried That Failed

1. **[What was tried]** — [why it didn't work]

## Open Questions / Blockers

1. [Question or blocker]
2. [Question or blocker]

## Gotchas / Warnings

- [Things the next session should watch out for]

## Suggested First Action

[The single most important thing for next session to do first]

## Files Changed

- Created: [list]
- Modified: [list]

---

## Handover Quality Feedback (for next session)

Did this handover help? [ ]
What was missing?
What was unnecessary?
```

## Quality Criteria

A good handover enables someone unfamiliar to continue work. Check:

- [ ] Can someone continue without re-reading all task files?
- [ ] Are implicit relationships made explicit?
- [ ] Is the "why" captured, not just the "what"?
- [ ] Are failed approaches documented (to prevent repetition)?
- [ ] Is the suggested first action clear and actionable?

## Integration

### With Session Capture (P-007)

Handover **includes** session capture as first step:
```
1. Session capture → ensure all work has tasks
2. Handover synthesis → create forward-looking summary
3. Write handover → persist for next session
```

### With CLAUDE.md

CLAUDE.md should instruct:
```
## Session Start Protocol
1. Read `.context/handovers/LATEST.md`
2. Review active tasks
3. Run `./metrics.sh`
```

### With Audit Agent

Audit can validate:
- Handover exists for recent sessions
- Handover has required sections
- LATEST.md is current

## Minimum Viable Handover

If pressed for time, capture at minimum:

1. **Where we are** (1-2 sentences)
2. **Active tasks with next steps** (one line each)
3. **Key decisions** (especially rejected alternatives)
4. **Blockers** (what's stuck)
5. **Start here** (single most important next action)

## What Handover is NOT

- Not a duplicate of task files (reference them, don't copy)
- Not a complete session transcript (synthesize, don't dump)
- Not a commit log (git has that)
- Not a status report (metrics.sh does that)

Handover is **strategic context** — the understanding layer above the data.

## Making Handover Antifragile

Each handover should improve the next:

1. **Feedback loop:** Next session reports what was missing/unnecessary
2. **Template evolution:** Bad patterns get fixed in template
3. **Practice extraction:** Good handover patterns become practices

## Example Usage

```bash
# Interactive mode (recommended)
./agents/handover/handover.sh

# With explicit session ID
./agents/handover/handover.sh --session "S-2026-0213-001"
```

## Related

- `agents/session-capture/AGENT.md` — Prerequisite for handover
- `001-Vision.md` — Project-level context (complements handover)
- `015-Practices.md` — Learnings graduate from handover to practices
- `.context/handovers/LATEST.md` — Entry point for new sessions
