---
id: T-1267
name: "Fix context_learning.bats + context_decision.bats destroying framework YAML"
description: >
  Implementation of T-1258 GO recommendation — alias FRAMEWORK_ROOT=TEST_TEMP_DIR
  in the two offending tests

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [tests/unit/context_decision.bats, tests/unit/context_learning.bats]
related_tasks: []
created: 2026-04-15T18:58:11Z
last_update: '2026-08-16T22:24:27Z'
date_finished: 2026-04-15T19:11:07Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:44Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:27Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1267: Fix context_learning.bats + context_decision.bats destroying framework YAML

## Context

Implementation of T-1258 RCA recommendation. Two unit tests redirect `PROJECT_ROOT` to the real `FRAMEWORK_ROOT` to exercise the `id_prefix=L/D` branch in `do_add_learning` and `do_add_decision`, then `rm -f` the real framework YAML. Fix aliases `FRAMEWORK_ROOT=TEST_TEMP_DIR` so the id_prefix branch is still taken but all file ops stay in the bats temp dir. See `docs/reports/T-1258-add-learning-truncation-rca.md` for the full RCA.

## Acceptance Criteria

### Agent
- [x] `tests/unit/context_learning.bats:60-76` — aliases FRAMEWORK_ROOT to TEST_TEMP_DIR instead of PROJECT_ROOT=$FRAMEWORK_ROOT
- [x] `tests/unit/context_decision.bats:60-76` — same fix for decisions.yaml bug class
- [x] All 10 context_learning tests pass post-fix
- [x] All 11 context_decision tests pass post-fix
- [x] Framework `.context/project/learnings.yaml` unchanged after test run (verified: 1709 → 1709 lines)
- [x] Framework `.context/project/decisions.yaml` unchanged after test run (verified: 24 → 24 lines)

## Verification

grep -q "FRAMEWORK_ROOT=\"\$TEST_TEMP_DIR\"" tests/unit/context_learning.bats
grep -q "FRAMEWORK_ROOT=\"\$TEST_TEMP_DIR\"" tests/unit/context_decision.bats
bats tests/unit/context_learning.bats tests/unit/context_decision.bats

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

### 2026-04-15T18:58:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1267-fix-contextlearningbats--contextdecision.md
- **Context:** Initial task creation

### 2026-04-15T19:11:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ce6e36c1
- **Timestamp:** 2026-06-02T14:56:19Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#5 (Agent)** — Framework `.context/project/learnings.yaml` unchanged after test run (verified: 1709 → 1709 lines)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/project/learnings.yaml in: Framework `.context/project/learnings.yaml` unchanged after test run (verified: 1709 → 1709 lines)`
- **AC#6 (Agent)** — Framework `.context/project/decisions.yaml` unchanged after test run (verified: 24 → 24 lines)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/project/decisions.yaml in: Framework `.context/project/decisions.yaml` unchanged after test run (verified: 24 → 24 lines)`
