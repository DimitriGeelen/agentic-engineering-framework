---
id: T-764
name: "Add unit tests for core libs — tasks, yaml, keylock, enums, paths"
description: >
  Add unit tests for core libs — tasks, yaml, keylock, enums, paths

status: work-completed
workflow_type: test
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-03-30T12:15:06Z
last_update: '2026-06-11T22:24:29Z'
date_finished: 2026-03-30T12:23:52Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:29Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-764: Add unit tests for core libs — tasks, yaml, keylock, enums, paths

## Context

Continuation of T-762 unit test expansion. Five core libs lack unit tests: tasks.sh (lookup), yaml.sh (field extraction), keylock.sh (locking), enums.sh (validation), paths.sh (resolution).

## Acceptance Criteria

### Agent
- [x] Unit tests for lib/tasks.sh — find_task_file, task_exists, get_task_name (10 tests)
- [x] Unit tests for lib/yaml.sh — get_yaml_field (8 tests)
- [x] Unit tests for lib/enums.sh — is_valid_status, is_valid_type, is_valid_transition (23 tests)
- [x] Unit tests for lib/keylock.sh — keylock_acquire, keylock_release (9 tests)
- [x] Unit tests for lib/paths.sh — variable resolution (5 tests)
- [x] All new tests pass (55/55)

### Human
<!-- No human ACs — all agent-verifiable -->

         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

bats tests/unit/lib_tasks.bats tests/unit/lib_yaml.bats tests/unit/lib_enums.bats tests/unit/lib_keylock.bats tests/unit/lib_paths.bats

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     Examples:
       python3 -c "import yaml; yaml.safe_load(open('path/to/file.yaml'))"
       curl -sf http://localhost:3000/page
       grep -q "expected_string" output_file.txt
-->

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

### 2026-03-30T12:15:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-764-add-unit-tests-for-core-libs--tasks-yaml.md
- **Context:** Initial task creation

### 2026-03-30T12:23:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0a9ab9e7
- **Timestamp:** 2026-06-02T15:04:48Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
