---
id: T-788
name: "Unit tests for remaining lib files — ask, build, harvest, init, promote, upstream,
  validate-init"
description: >
  Unit tests for remaining lib files — ask, build, harvest, init, promote, upstream,
  validate-init

status: work-completed
workflow_type: test
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-03-30T13:55:50Z
last_update: '2026-06-11T22:24:29Z'
date_finished: 2026-03-30T14:04:15Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:29Z'
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

# T-788: Unit tests for remaining lib files — ask, build, harvest, init, promote, upstream, validate-init

## Context

Continuing unit test coverage expansion from T-780 (10 test files, 105 tests). Remaining untested lib files: first-run, harvest, init, promote, upgrade, validate-init. Files with `set -euo pipefail` at top level (ask, build, upstream) are skipped — not safely sourceable in bats.

## Acceptance Criteria

### Agent
- [x] Unit tests for lib/first-run.sh (do_first_run output, structure) — 9 tests
- [x] Unit tests for lib/harvest.sh (argument parsing, help, guards, sub-functions) — 11 tests
- [x] Unit tests for lib/init.sh (argument parsing, help, guards, generator existence) — 10 tests
- [x] Unit tests for lib/validate-init.sh (argument parsing, help, validation logic) — 8 tests
- [x] Unit tests for lib/promote.sh (argument parsing, help, routing) — 8 tests
- [x] Unit tests for lib/upgrade.sh (argument parsing, help, guards) — 9 tests
- [x] All new tests pass: bats tests/unit/lib_*.bats exits 0 — 419 total, 0 failures
- [x] No regressions in existing test suite

## Verification

bats tests/unit/lib_first_run.bats
bats tests/unit/lib_harvest.bats
bats tests/unit/lib_init.bats
bats tests/unit/lib_validate_init.bats
bats tests/unit/lib_promote.bats
bats tests/unit/lib_upgrade.bats
bats tests/unit/

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

### 2026-03-30T13:55:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-788-unit-tests-for-remaining-lib-files--ask-.md
- **Context:** Initial task creation

### 2026-03-30T14:04:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9ce0e6d9
- **Timestamp:** 2026-06-02T15:04:52Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
