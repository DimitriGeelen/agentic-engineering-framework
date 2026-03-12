---
id: T-475
name: "Add bats tests for 9 uncovered gate scripts"
description: >
  Write ~55 new bats tests covering: budget-gate.sh (15), block-plan-mode.sh (3), check-dispatch.sh (5), check-fabric-new-file.sh (5), checkpoint.sh (8), bus-handler.sh (5), pre-compact.sh (5), post-compact-resume.sh (5). Follow existing test_helper.bash patterns. Phase 2 of T-473 GO.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [testing, D2]
components: []
related_tasks: []
created: 2026-03-12T21:31:04Z
last_update: 2026-03-12T21:31:04Z
date_finished: null
---

# T-475: Add bats tests for 9 uncovered gate scripts

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] [First criterion]
- [ ] [Second criterion]

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

### 2026-03-12T21:31:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-475-add-bats-tests-for-9-uncovered-gate-scri.md
- **Context:** Initial task creation
