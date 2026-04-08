# T-1067: Horizon-Status Invariant Enforcement

## Problem Statement

The `horizon` field (now/next/later) and `status` field (captured/started-work/work-completed/issues) can be set independently, creating contradictory states:

| Status | Horizon | Count | Contradiction |
|--------|---------|-------|---------------|
| started-work | next | 10 | "Active" but "not yet" |
| started-work | later | 18 | "Active" but "parked" |
| work-completed | now | 33 | "Done" but "urgent priority" |

**61 tasks** currently have inconsistent state.

## Impact

1. **Handover noise**: 28 parked tasks appear under "Work in Progress" because status=started-work
2. **Priority pollution**: 33 done tasks sit at horizon=now, crowding out real priorities
3. **Signal degradation**: The handover's "Suggested First Action" scans horizon:now/next for started-work tasks — ghost tasks dilute selection
4. **Concurrent task warning spam**: `update-task.sh` reports "46 other tasks already in started-work" — most are parked, not concurrent

## Root Cause

`update-task.sh` treats `--status` and `--horizon` as independent fields. No invariant enforcement exists:
- Line 382-411: status change logic (no horizon check)
- Line 476-492: horizon change logic (no status check)
- `fw work-on T-XXX` (bin/fw:2647): sets status=started-work but doesn't touch horizon

## Proposed Invariants

### Invariant 1: started-work → horizon: now
**When:** `--status started-work` is set
**Action:** Auto-set `horizon: now` (with info message)
**Rationale:** Starting work means it's active NOW. No scenario where you start work on something scheduled for later.

### Invariant 2: horizon next/later → status: captured (if started-work)
**When:** `--horizon next` or `--horizon later` is set AND current status is `started-work`
**Action:** Auto-demote status to `captured` (with info message)
**Rationale:** Shelving a task means you stopped working on it. Can't be "in progress" and "parked."

### Invariant 3: work-completed in active/
**When:** Task has status=work-completed but lives in .tasks/active/
**Observation:** 33 tasks in this state. The completion handler (line 620+) moves tasks to completed/, so these were either force-completed or manually edited.
**Action:** One-time cleanup to move them. No new enforcement needed (mechanism exists).

## Implementation Locations

All changes in `agents/task-create/update-task.sh`:

1. **After status update block (~line 420)**: If new status is started-work, auto-set horizon to now
2. **After horizon update block (~line 492)**: If new horizon is next/later AND current status is started-work, auto-set status to captured
3. **One-time cleanup script**: Fix 61 existing inconsistent tasks

## Alternatives Considered

### A. Warn-only (no auto-fix)
- Print warning when invariant violated
- Agent/human must fix manually
- **Rejected:** Creates noise without fixing the problem. Same warning will fire every session.

### B. Block (hard gate)
- Reject the update if it would create inconsistency
- **Rejected:** Too strict. `fw task update T-XXX --horizon later` would fail, forcing two commands instead of one.

### C. Auto-sync (proposed)
- Automatically maintain consistency with info message
- User sees what happened, can override if needed
- **Preferred:** Graduated enforcement pattern (SP-004) — detect AND prevent in one step.

## Edge Cases

1. **`--status started-work --horizon later` in same command**: Which wins? Status wins → horizon auto-promoted to now. The explicit horizon is ignored with warning.
2. **`issues` status + horizon change**: No auto-demotion. `issues` is a problem state, not "parked."
3. **`blocked` status + horizon change**: Same as issues — no auto-demotion.
4. **`captured` + horizon now**: Valid. "Ready to work on, not started yet."

## Scope

**IN:**
- Invariant enforcement in update-task.sh (2 blocks, ~20 lines)
- One-time data cleanup (dry-run + execute)
- CLAUDE.md documentation of invariant rules

**OUT:**
- Changes to handover enricher (already groups by horizon correctly)
- Changes to create-task.sh (new tasks get sane defaults)
- Retroactive analysis of how tasks got into bad state

## Go/No-Go Criteria

**GO if:**
- Implementation is < 30 lines of bash in update-task.sh
- One-time cleanup can be done safely (dry-run first)
- No existing workflow relies on started-work + horizon:later as intentional state

**NO-GO if:**
- There's a legitimate use case for started-work + horizon:next (e.g., "partially started, paused for higher priority")
- The auto-demotion would break the healing loop or other auto-triggers

## Dialogue Log

### Exchange 1: User identifies the deficiency
**User:** "notice in progress there are tasks that have horizon next and later, this cannot be anything we are working on has horizon now right ??? seems a workflow deficiency / omission"
**Agent:** Investigated — found 28 started-work tasks with horizon!=now, 33 work-completed tasks with horizon=now. Confirmed this is a structural gap in update-task.sh.
**Outcome:** User said "please incept" — confirmed this warrants formal exploration.
