---
id: T-766
name: "Add unit tests for lib/compat.sh and lib/runtime.sh"
description: >
  Add unit tests for lib/compat.sh and lib/runtime.sh

status: work-completed
workflow_type: test
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-30T12:26:41Z
last_update: 2026-03-30T12:28:58Z
date_finished: 2026-03-30T12:28:58Z
---

# T-766: Add unit tests for lib/compat.sh and lib/runtime.sh

## Context

Continuation of T-762/T-764/T-765 unit test expansion. compat.sh (_sed_i portable sed) and runtime.sh (fw_run_ts TypeScript/Python fallback) have no tests.

## Acceptance Criteria

### Agent
- [x] Unit tests for lib/compat.sh — _sed_i function (7 tests)
- [x] Unit tests for lib/runtime.sh — fw_run_ts function (5 tests)
- [x] All new tests pass (12/12)

### Human
<!-- No human ACs — all agent-verifiable -->
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

bats tests/unit/lib_compat.bats tests/unit/lib_runtime.bats

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

### 2026-03-30T12:26:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-766-add-unit-tests-for-libcompatsh-and-libru.md
- **Context:** Initial task creation

### 2026-03-30T12:28:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
