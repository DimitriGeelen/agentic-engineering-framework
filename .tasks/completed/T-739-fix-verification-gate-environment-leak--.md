---
id: T-739
name: "Fix verification gate environment leak — unset TASKS_DIR/CONTEXT_DIR before
  eval"
description: >
  Verification gate runs commands with exported TASKS_DIR/CONTEXT_DIR from parent,
  so child processes that override PROJECT_ROOT still inherit stale TASKS_DIR. Fix:
  run verification commands in a subshell with framework path derivatives unset.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-29T23:07:26Z
last_update: '2026-08-16T22:25:38Z'
date_finished: 2026-03-29T23:09:12Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:28Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:38Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-739: Fix verification gate environment leak — unset TASKS_DIR/CONTEXT_DIR before eval

## Context

Root cause: `update-task.sh` exports `TASKS_DIR`/`CONTEXT_DIR` via `paths.sh:42`. When verification commands run bats tests that override `PROJECT_ROOT`, `paths.sh:38` (`TASKS_DIR="${TASKS_DIR:-...}"`) preserves the stale inherited value. Result: tasks created in tests pollute real `.tasks/active/`. Evidence: commit `432e4060` cleaned up 9 spurious tasks (T-739–T-747).

## Acceptance Criteria

### Agent
- [x] Verification gate runs commands in a subshell with `TASKS_DIR`, `CONTEXT_DIR`, `_FW_PATHS_LOADED` unset
- [x] Existing verification commands still pass (simple checks like `test -f`, `grep`, `curl`)
- [x] A bats test that creates tasks via `fw task create` does NOT create files in framework `.tasks/active/`
- [x] Integration tests pass: `bats tests/integration/fw_task.bats`

## Verification

# The subshell approach is present in update-task.sh
grep -q "unset TASKS_DIR CONTEXT_DIR" agents/task-create/update-task.sh
# Integration tests pass
bats tests/integration/fw_task.bats
bats tests/integration/fw_context.bats

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

### 2026-03-29T23:07:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-739-fix-verification-gate-environment-leak--.md
- **Context:** Initial task creation

### 2026-03-29T23:09:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4fbb45aa
- **Timestamp:** 2026-06-02T15:04:39Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
