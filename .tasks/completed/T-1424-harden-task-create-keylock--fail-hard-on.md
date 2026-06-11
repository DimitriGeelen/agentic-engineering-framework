---
id: T-1424
name: "harden task-create keylock — fail hard on source/primitive miss (T-1279 followup)"
description: >
  T-1279's fix (keylock around ID allocation) fails silently when source errors or
  when keylock_acquire is unavailable: line 18 uses || true, line 143 uses type guard.
  Previous session reproduced 3-way collision on T-1424 without subshell wrap. Remove
  silent skips; fail fast.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-24T12:55:59Z
last_update: '2026-06-11T22:23:48Z'
date_finished: 2026-04-24T12:59:27Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:48Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 3
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=3 (body:component-silent-failure); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1424: harden task-create keylock — fail hard on source/primitive miss (T-1279 followup)

## Context

T-1279 landed a keylock around task-ID allocation in `agents/task-create/create-task.sh` (line 18 source + line 143 guard) to fix a read-then-write TOCTOU race producing duplicate IDs. Previous session (S-2026-0424-1426) ran a 10-parallel reproduction without subshell wrap and observed a 3-way collision on T-1424, suggesting the fix is not watertight in all call patterns. Regardless of whether that specific race is still reachable, the current code has two silent-skip paths (`source ... || true` and `if type keylock_acquire`) that violate framework doctrine (no silent failures). This task removes both and fails loudly if the lock primitive can't be loaded.

## Acceptance Criteria

### Agent
- [x] `source "$FRAMEWORK_ROOT/lib/keylock.sh"` in create-task.sh uses no `|| true` — failure exits with non-zero
- [x] Explicit `type keylock_acquire` assertion after source — missing primitive exits with non-zero
- [x] The `if type keylock_acquire; then` guard at line ~143 is removed — `keylock_acquire` is called unconditionally
- [x] `bats tests/unit/task_id_race.bats` all tests pass after the change (5/5 including 2 new T-1424 tests)
- [x] A new bats test proves create-task.sh exits non-zero when keylock.sh is absent

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

grep -q 'source "$FRAMEWORK_ROOT/lib/keylock.sh" || {' agents/task-create/create-task.sh
grep -q 'type keylock_acquire' agents/task-create/create-task.sh
! grep -q 'keylock.sh" 2>/dev/null || true' agents/task-create/create-task.sh
bats tests/unit/task_id_race.bats

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-24T12:55:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1424-harden-task-create-keylock--fail-hard-on.md
- **Context:** Initial task creation

### 2026-04-24T12:59:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cca008bb
- **Timestamp:** 2026-06-02T14:57:23Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
