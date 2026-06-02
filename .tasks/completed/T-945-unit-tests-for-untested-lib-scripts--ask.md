---
id: T-945
name: "Unit tests for untested lib scripts — ask.sh, first-run.sh, validate-init.sh"
description: >
  Unit tests for untested lib scripts — ask.sh, first-run.sh, validate-init.sh

status: work-completed
workflow_type: test
owner: agent
horizon: null
tags: []
components: [tests/unit/lib_ask.bats, tests/unit/lib_first_run.bats, tests/unit/lib_validate_init.bats]
related_tasks: []
created: 2026-04-06T10:37:15Z
last_update: 2026-04-06T10:40:39Z
date_finished: 2026-04-06T10:40:39Z
---

# T-945: Unit tests for untested lib scripts — ask.sh, first-run.sh, validate-init.sh

## Context

Three lib scripts with no test coverage. ask.sh is thin (delegates to Python), first-run.sh runs fw commands, validate-init.sh has substantial logic.

## Acceptance Criteria

### Agent
- [x] tests/unit/lib_ask.bats created (5 tests)
- [x] tests/unit/lib_first_run.bats created (4 tests)
- [x] tests/unit/lib_validate_init.bats created (7 tests)
- [x] All new tests pass (16/16)
- [x] Fabric cards registered (3 cards)

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

### 2026-04-06T10:37:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-945-unit-tests-for-untested-lib-scripts--ask.md
- **Context:** Initial task creation

### 2026-04-06T10:40:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5fb7e629
- **Timestamp:** 2026-06-02T15:05:49Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#1 (Agent)** — tests/unit/lib_ask.bats created (5 tests)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/unit/lib_ask.bats in: tests/unit/lib_ask.bats created (5 tests)`
- **AC#2 (Agent)** — tests/unit/lib_first_run.bats created (4 tests)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/unit/lib_first_run.bats in: tests/unit/lib_first_run.bats created (4 tests)`
- **AC#3 (Agent)** — tests/unit/lib_validate_init.bats created (7 tests)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/unit/lib_validate_init.bats in: tests/unit/lib_validate_init.bats created (7 tests)`
