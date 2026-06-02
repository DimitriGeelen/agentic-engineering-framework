---
id: T-750
name: "Add integration tests for fw init, version, help, onboarding, validate-init (13 tests)"
description: >
  Integration tests for more untested fw CLI commands.

status: work-completed
workflow_type: test
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-30T00:09:27Z
last_update: 2026-03-30T00:14:27Z
date_finished: 2026-03-30T00:14:27Z
---

# T-750: Add integration tests for fw init, version, help, onboarding, validate-init (13 tests)

## Context

Continuing integration test expansion for untested fw CLI commands.

## Acceptance Criteria

### Agent
- [x] fw_version.bats created with 2+ tests
- [x] fw_help.bats created with 2+ tests
- [x] fw_init.bats created with 3+ tests
- [x] fw_onboarding.bats created with 2+ tests
- [x] fw_validate_init.bats created with 2+ tests
- [x] All new tests pass
- [x] Component cards created

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

bats tests/integration/fw_version.bats
bats tests/integration/fw_help.bats
bats tests/integration/fw_init.bats
bats tests/integration/fw_onboarding.bats
bats tests/integration/fw_validate_init.bats

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

### 2026-03-30T00:09:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-750-add-integration-tests-for-fw-init-versio.md
- **Context:** Initial task creation

### 2026-03-30T00:14:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-043c07ea
- **Timestamp:** 2026-06-02T15:04:43Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
