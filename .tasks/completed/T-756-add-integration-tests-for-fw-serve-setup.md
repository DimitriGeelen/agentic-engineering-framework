---
id: T-756
name: "Add integration tests for fw serve, setup, update, upgrade, scan, self-audit
  (12 tests)"
description: >
  Add integration tests for fw serve, setup, update, upgrade, scan, self-audit (12
  tests)

status: work-completed
workflow_type: test
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-30T07:10:55Z
last_update: '2026-06-11T22:24:29Z'
date_finished: 2026-03-30T07:13:29Z
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

# T-756: Add integration tests for fw serve, setup, update, upgrade, scan, self-audit (12 tests)

## Context

Continue expanding integration test coverage: serve, setup, update, upgrade, scan, self-audit.

## Acceptance Criteria

### Agent
- [x] fw_serve.bats created with 1 test (status reporting)
- [x] fw_setup.bats created with 2 tests (deprecation notice, task setup output)
- [x] fw_update.bats created with 2 tests (help, --check version info)
- [x] fw_upgrade.bats created with 2 tests (help, --dry-run shows changes)
- [x] fw_scan.bats created with 2 tests (empty project scan, creates scan file)
- [x] fw_self_audit.bats created with 2 tests (audit report, foundation layer)
- [x] All new tests pass: 11/11 passing

## Verification

bats tests/integration/fw_serve.bats
bats tests/integration/fw_setup.bats
bats tests/integration/fw_update.bats
bats tests/integration/fw_upgrade.bats
bats tests/integration/fw_scan.bats
bats tests/integration/fw_self_audit.bats

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

### 2026-03-30T07:10:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-756-add-integration-tests-for-fw-serve-setup.md
- **Context:** Initial task creation

### 2026-03-30T07:13:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8c3d4642
- **Timestamp:** 2026-06-02T15:04:45Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
