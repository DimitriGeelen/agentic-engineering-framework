---
id: T-1366
name: "keylock_acquire: add optional timeout (flock -w)"
description: >
  lib/keylock.sh keylock_acquire blocks forever by default. Add optional timeout (flock
  -w N) so callers can fail fast on deadlock. Deferred from T-1279 AC.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-20T19:38:24Z
last_update: '2026-06-11T22:23:46Z'
date_finished: 2026-04-20T19:48:43Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1366: keylock_acquire: add optional timeout (flock -w)

## Context

Deferred from T-1279. `keylock_acquire` currently calls `flock -x` (block forever). For task-id-allocation this is acceptable because the critical section is short, but future callers may want fail-fast semantics to avoid hung processes on deadlock. Optional 2nd arg = timeout in seconds → `flock -w N`.

## Acceptance Criteria

### Agent
- [x] `keylock_acquire <key> [timeout_seconds]` — optional 2nd arg
- [x] If timeout provided and exceeded, function returns non-zero (flock -w exit 1)
- [x] Omitting timeout preserves block-forever behavior (backward compatible)
- [x] Bats test `tests/unit/lib_keylock_timeout.bats` — 4 tests, all pass. Non-regression lib_keylock.bats (9 tests) still pass.

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

# Shell commands that MUST pass before work-completed. One per line.
bats tests/unit/lib_keylock_timeout.bats
# Non-regression: existing keylock tests still pass
bats tests/unit/lib_keylock.bats

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

### 2026-04-20T19:38:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1366-keylockacquire-add-optional-timeout-floc.md
- **Context:** Initial task creation

### 2026-04-20T19:44:11Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-20T19:48:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-75e3f5f1
- **Timestamp:** 2026-06-02T14:56:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
