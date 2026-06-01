---
id: T-1067
name: "Horizon-status invariant enforcement — auto-sync horizon and status in update-task.sh"
description: >
  Inception: Horizon-status invariant enforcement — auto-sync horizon and status in update-task.sh

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-08T10:18:04Z
last_update: 2026-04-13T06:23:14Z
date_finished: 2026-04-08T10:31:50Z
---

# T-1067: Horizon-status invariant enforcement — auto-sync horizon and status in update-task.sh

## Problem Statement

`horizon` (now/next/later) and `status` (captured/started-work/work-completed) are set independently in `update-task.sh`, creating contradictory states. Currently **61 tasks** are inconsistent: 28 have started-work + horizon:next/later ("active but parked"), 33 have work-completed + horizon:now ("done but urgent"). This degrades handover quality, inflates concurrent-task warnings (46 reported, most are parked), and dilutes the Suggested First Action signal.

**For:** Framework users and agents who rely on handover accuracy.
**Why now:** Observed during session review — the "Work in Progress" section is unreadable.

Research artifact: `docs/reports/T-1067-horizon-status-invariants.md`

## Assumptions

- A-001: No workflow intentionally uses started-work + horizon:later (to be verified by checking if any task was deliberately set this way)
- A-002: Auto-sync is preferable to blocking (users want one command, not two)
- A-003: The 33 work-completed tasks in active/ are from --force bypasses or manual edits, not a broken completion handler

## Exploration Plan

1. **Verify A-001** (~5 min): Check git log for intentional `--horizon later --status started-work` combinations
2. **Verify A-003** (~5 min): Check if completion handler (line 620+) has a bug or if these are all --force
3. **Prototype invariant** (~10 min): Draft the bash additions, verify they don't break existing tests
4. **Dry-run cleanup** (~5 min): Script to show what would change, without changing

## Technical Constraints

None — this is pure bash in an existing script. No platform, network, or API concerns.

## Scope Fence

**IN:** Invariant enforcement in update-task.sh, one-time cleanup, CLAUDE.md docs
**OUT:** Handover enricher changes, create-task.sh changes, retroactive analysis

## Acceptance Criteria

### Agent
- [x] Problem statement validated with data (151 active, 100 work-completed, 28 wrong-horizon started-work, 24 stuck completed)
- [x] Assumptions A-016 through A-018 tested with evidence (all validated)
- [x] No existing workflow broken by auto-sync (11/11 update_task.bats pass; test 7 will need update for new invariant)
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw task review T-1067`
  2. Review the invariant rules and confirm no legitimate use case for started-work + later
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Implementation is < 30 lines of bash in update-task.sh
- One-time cleanup can be done safely (dry-run verifies no data loss)
- No existing workflow relies on started-work + horizon:later as intentional state
- Existing tests pass with invariant enforcement added

**NO-GO if:**
- There's a legitimate use case for started-work + horizon:next (e.g., partially started, paused)
- Auto-demotion would break the healing loop or other auto-triggers
- Data cleanup reveals tasks that were intentionally set to contradictory state

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO

**Rationale:** The deficiency is clear (61+ inconsistent tasks), the fix is small (~20 lines in update-task.sh), all assumptions validated, and the approach follows established SP-004 graduated enforcement pattern. No legitimate use case for the contradictory states exists. One existing test (test 7: "changes horizon") will need updating to expect the auto-demotion behavior.

**Evidence:**
- 28 started-work tasks with horizon != now (should be now or status should be captured)
- 100 work-completed tasks in active/ (76 legitimate partial-complete, 24 stuck)
- Git log shows no intentional started-work + later combinations (A-016 validated)
- 11/11 update_task.bats pass at baseline
- "46 other tasks in started-work" warning is 99% noise from parked tasks

**Build scope (3 tasks):**
1. **Invariant enforcement** in update-task.sh (~20 lines) + test updates
2. **One-time cleanup script** for 28 wrong-horizon + 24 stuck-completed tasks
3. **CLAUDE.md update** documenting the invariant rules

## Decisions

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: The deficiency is clear (61+ inconsistent tasks), the fix is small (~20 lines in update-task.sh), all assumptions validated, and the approach follows established SP-004 graduated enforcement pattern. No legitimate use case for the contradictory states exists. One existing test (test 7: "changes horizon") will need updating to expect the auto-demotion behavior.

Evidence:
- 28 started-work tasks with horizon != now (should be now or status should be captured)
- 1...

**Date**: 2026-04-08T10:31:50Z
## Decision

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: The deficiency is clear (61+ inconsistent tasks), the fix is small (~20 lines in update-task.sh), all assumptions validated, and the approach follows established SP-004 graduated enforcement pattern. No legitimate use case for the contradictory states exists. One existing test (test 7: "changes horizon") will need updating to expect the auto-demotion behavior.

Evidence:
- 28 started-work tasks with horizon != now (should be now or status should be captured)
- 1...

**Date**: 2026-04-08T10:31:50Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-08T10:19:47Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-08T10:31:50Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: The deficiency is clear (61+ inconsistent tasks), the fix is small (~20 lines in update-task.sh), all assumptions validated, and the approach follows established SP-004 graduated enforcement pattern. No legitimate use case for the contradictory states exists. One existing test (test 7: "changes horizon") will need updating to expect the auto-demotion behavior.

Evidence:
- 28 started-work tasks with horizon != now (should be now or status should be captured)
- 1...

### 2026-04-08T10:31:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-12T09:27:15Z — status-update [task-update-agent]
- **Change:** horizon: now → next
