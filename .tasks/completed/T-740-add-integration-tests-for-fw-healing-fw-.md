---
id: T-740
name: "Add integration tests for fw healing, fw git, and fw work-on CLI commands"
description: >
  Integration test coverage gaps: fw healing (diagnose, patterns, suggest), fw git (commit, status), fw work-on (create+focus, resume). Add bats tests following existing patterns.

status: work-completed
workflow_type: test
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-29T23:10:04Z
last_update: 2026-03-29T23:19:02Z
date_finished: 2026-03-29T23:19:02Z
---

# T-740: Add integration tests for fw healing, fw git, and fw work-on CLI commands

## Context

Test coverage gap: fw healing, fw git, and fw work-on have no integration tests. Pattern: follow existing `fw_task.bats` / `fw_context.bats` patterns with temp dir isolation.

## Acceptance Criteria

### Agent
- [x] `tests/integration/fw_healing.bats` created with tests for help, diagnose, patterns, suggest
- [x] `tests/integration/fw_git.bats` created with tests for help, status, commit
- [x] `tests/integration/fw_work_on.bats` created with tests for create+focus and resume
- [x] All new tests pass: `bats tests/integration/fw_healing.bats tests/integration/fw_git.bats tests/integration/fw_work_on.bats`
- [x] Existing tests still pass
- [x] Component cards registered for new test files

### Human
<!-- No human ACs needed — agent-verifiable tests
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# Test files exist
test -f tests/integration/fw_healing.bats
test -f tests/integration/fw_git.bats
test -f tests/integration/fw_work_on.bats
# Component cards exist
test -f .fabric/components/tests-integration-fw_healing.yaml
test -f .fabric/components/tests-integration-fw_git.yaml
test -f .fabric/components/tests-integration-fw_work_on.yaml
# Tests pass
bats tests/integration/fw_healing.bats
bats tests/integration/fw_git.bats
bats tests/integration/fw_work_on.bats

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

### 2026-03-29T23:10:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-740-add-integration-tests-for-fw-healing-fw-.md
- **Context:** Initial task creation

### 2026-03-29T23:19:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-799abdff
- **Timestamp:** 2026-06-02T15:04:40Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
