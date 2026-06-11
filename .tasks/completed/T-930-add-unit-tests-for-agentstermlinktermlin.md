---
id: T-930
name: "Add unit tests for agents/termlink/termlink.sh"
description: >
  Add unit tests for agents/termlink/termlink.sh

status: work-completed
workflow_type: test
owner: agent
horizon:
tags: []
components: [tests/unit/termlink.bats]
related_tasks: []
created: 2026-04-05T16:24:53Z
last_update: '2026-06-11T22:24:32Z'
date_finished: 2026-04-05T16:26:04Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:32Z'
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

# T-930: Add unit tests for agents/termlink/termlink.sh

## Context

TermLink wrapper agent has no tests. Testing help, check, status, and routing.

## Acceptance Criteria

### Agent
- [x] Test file exists at tests/unit/termlink.bats
- [x] Tests cover help, check, status, cleanup, dispatch validation, unknown command
- [x] All tests pass (8/8)

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

### 2026-04-05T16:24:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-930-add-unit-tests-for-agentstermlinktermlin.md
- **Context:** Initial task creation

### 2026-04-05T16:26:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5a4aeb8b
- **Timestamp:** 2026-06-02T15:05:43Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — Test file exists at tests/unit/termlink.bats
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/unit/termlink.bats in: Test file exists at tests/unit/termlink.bats`
