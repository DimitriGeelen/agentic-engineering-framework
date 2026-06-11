---
id: T-1515
name: "Fix do_inception_decide silent failure: propagate update-task.sh exit code
  (T-1491 root cause)"
description: >
  Fix do_inception_decide silent failure: propagate update-task.sh exit code (T-1491
  root cause)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-26T20:32:09Z
last_update: '2026-06-11T22:23:50Z'
date_finished: 2026-04-26T20:34:32Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:50Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 3
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=3 
      (body:component-silent-failure); D3=0 (no-signal); D4=0 (no-signal); 
      F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1515: Fix do_inception_decide silent failure: propagate update-task.sh exit code (T-1491 root cause)

## Context

T-1491 RCA found that `do_inception_decide` in `lib/inception.sh:488,490` calls `update-task.sh --status work-completed` and discards the exit code. If P-010 (AC gate), P-011 (verification gate), or any other failure causes the status transition to fail, the user still sees `Inception decision recorded` and the function returns 0 — leaving the task in a class 2 stuck state (started-work + Decision recorded).

T-1514 just shipped reactive recovery via the sweep. This task ships the prevention: capture the exit code, if non-zero print a clear failure message pointing to remediation tools, and propagate the failure up.

## Acceptance Criteria

### Agent
- [x] `do_inception_decide` captures the exit code from each `update-task.sh` invocation (the `captured → started-work` step at line 488 and the `→ work-completed` step at line 490)
- [x] On non-zero exit: print clear error pointing to `fw inception sweep` (recovery) and `fw task verify` (diagnostic), do not print the success line, and return non-zero from `do_inception_decide`
- [x] On zero exit: existing behavior preserved (success line, emit_review, next-step hint)
- [x] Bats test in `tests/unit/` simulates a failing `update-task.sh` and asserts the function reports failure with non-zero exit code

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

# Bats test exists and passes
test -f tests/unit/inception_decide_propagate_exit.bats
bats tests/unit/inception_decide_propagate_exit.bats
# Code now captures exit code from update-task.sh (proves T-1515 fix is live)
grep -q "_uts_rc=\$?" lib/inception.sh
grep -q "T-1515" lib/inception.sh

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

### 2026-04-26T20:32:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1515-fix-doinceptiondecide-silent-failure-pro.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-746c3a99
- **Timestamp:** 2026-06-02T14:58:00Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-26T20:34:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Exit propagation + bats coverage; existing 21 inception tests still pass
