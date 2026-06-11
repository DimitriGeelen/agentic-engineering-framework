---
id: T-474
name: "Fix 16 failing bats tests (post-G-020 refactoring)"
description: >
  Fix the 16 failing tests across check_active_task.bats and unit tests. Failures
  are due to recent G-020 refactoring (check-active-task.sh now has placeholder AC
  detection). Update test expectations to match new gate behavior.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [testing, D2]
components: []
related_tasks: []
created: 2026-03-12T21:30:55Z
last_update: '2026-06-11T22:24:22Z'
date_finished: 2026-03-12T21:48:18Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:22Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=0
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-474: Fix 16 failing bats tests (post-G-020 refactoring)

## Context

Continuation of T-473 (GO). 22 tests failing across 4 test files due to: G-020 refactoring (check-active-task.sh), missing function sources (focus.sh, suggest.sh), removed function (score_pattern).

## Acceptance Criteria

### Agent
- [x] All bats tests pass: `bats tests/integration/ tests/unit/` exits 0 (151/151)
- [x] check_active_task.bats: B-005 settings.json test updated, task file fixtures added for G-013/G-020
- [x] context_focus.bats: lib/tasks.sh + lib/compat.sh sourced for find_task_file/get_task_name/_sed_i
- [x] healing_diagnose.bats: removed 10 score_pattern tests (function no longer exists)
- [x] healing_suggest.bats: lib/yaml.sh sourced for get_yaml_field
- [x] git_common.bats: lib/tasks.sh sourced, quote-stripping assertion fixed

## Verification

bats tests/integration/ tests/unit/

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

### 2026-03-12T21:30:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-474-fix-16-failing-bats-tests-post-g-020-ref.md
- **Context:** Initial task creation

### 2026-03-12T21:48:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-72f459b6
- **Timestamp:** 2026-06-02T15:03:02Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 4

**Per-AC findings:**

- **AC#3 (Agent)** — context_focus.bats: lib/tasks.sh + lib/compat.sh sourced for find_task_file/get_task_name/_sed_i
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/tasks.sh in: context_focus.bats: lib/tasks.sh + lib/compat.sh sourced for find_task_file/get_task_name/_sed_i`
- **AC#5 (Agent)** — healing_suggest.bats: lib/yaml.sh sourced for get_yaml_field
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/yaml.sh in: healing_suggest.bats: lib/yaml.sh sourced for get_yaml_field`
- **AC#6 (Agent)** — git_common.bats: lib/tasks.sh sourced, quote-stripping assertion fixed
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/tasks.sh in: git_common.bats: lib/tasks.sh sourced, quote-stripping assertion fixed`

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `bats tests/integration/ tests/unit/`
