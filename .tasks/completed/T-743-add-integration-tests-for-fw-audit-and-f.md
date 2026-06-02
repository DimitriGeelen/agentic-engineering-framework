---
id: T-743
name: "Add integration tests for fw audit and fw doctor CLI commands"
description: >
  No integration test coverage for fw audit (compliance) and fw doctor (health check). Add bats tests.

status: work-completed
workflow_type: test
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-29T23:27:40Z
last_update: 2026-03-29T23:30:17Z
date_finished: 2026-03-29T23:30:17Z
---

# T-743: Add integration tests for fw audit and fw doctor CLI commands

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `tests/integration/fw_audit.bats` created with 3 tests: help, section run, YAML output
- [x] `tests/integration/fw_doctor.bats` created with 4 tests: health check, installation, config, markers
- [x] All new tests pass
- [x] Component cards registered

## Verification

test -f tests/integration/fw_audit.bats
test -f tests/integration/fw_doctor.bats
bats tests/integration/fw_audit.bats
bats tests/integration/fw_doctor.bats

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

### 2026-03-29T23:27:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-743-add-integration-tests-for-fw-audit-and-f.md
- **Context:** Initial task creation

### 2026-03-29T23:30:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ea7ad7ef
- **Timestamp:** 2026-06-02T15:04:41Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
