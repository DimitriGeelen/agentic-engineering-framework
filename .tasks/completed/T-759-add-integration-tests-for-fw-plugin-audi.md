---
id: T-759
name: "Add integration tests for fw plugin-audit, test-onboarding, termlink (6 tests)"
description: >
  Add integration tests for fw plugin-audit, test-onboarding, termlink (6 tests)

status: work-completed
workflow_type: test
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-30T07:23:37Z
last_update: '2026-06-11T22:24:29Z'
date_finished: 2026-03-30T07:25:44Z
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

# T-759: Add integration tests for fw plugin-audit, test-onboarding, termlink (6 tests)

## Context

Final batch of integration tests for remaining untested fw CLI commands.

## Acceptance Criteria

### Agent
- [x] fw_plugin_audit.bats created with 2 tests (runs audit, shows counts)
- [x] fw_test_onboarding.bats created with 2 tests (runs test, checks scaffold)
- [x] fw_termlink.bats created with 2 tests (help, check installation)
- [x] All new tests pass: 6/6 passing

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

bats tests/integration/fw_plugin_audit.bats
bats tests/integration/fw_test_onboarding.bats
bats tests/integration/fw_termlink.bats

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

### 2026-03-30T07:23:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-759-add-integration-tests-for-fw-plugin-audi.md
- **Context:** Initial task creation

### 2026-03-30T07:25:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-694e7495
- **Timestamp:** 2026-06-02T15:04:47Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
