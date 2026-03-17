---
id: T-515
name: "Tier A E2E tests — 12 shell-level enforcement gate tests"
description: >
  Write 12 test scripts in tests/e2e/tier-a/ covering: task gate (A1-A2), commit hook (A3-A4), Tier 0 (A5-A6), budget gate (A7-A8), inception gate (A9), verification gate (A10), fw doctor (A11), audit (A12). Zero API cost. From T-513 inception build task 2.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [testing, termlink, D2]
components: []
related_tasks: []
created: 2026-03-17T21:10:29Z
last_update: 2026-03-17T21:21:22Z
date_finished: null
---

# T-515: Tier A E2E tests — 12 shell-level enforcement gate tests

## Context

From T-513 inception (GO) → T-514 scaffolding complete. See `docs/reports/T-513-termlink-testing-methodology.md`.

## Acceptance Criteria

### Agent
- [x] Test files exist in `tests/e2e/tier-a/` for gate scenarios
- [x] Tests use shared lib (setup.sh, teardown.sh, assert.sh)
- [x] All tests pass when run via `tests/e2e/runner.sh --tier a`
- [x] JSON output works: `tests/e2e/runner.sh --tier a --json`

## Verification

test $(ls tests/e2e/tier-a/test-*.sh 2>/dev/null | wc -l) -ge 4
! timeout 120 bash tests/e2e/runner.sh --tier a 2>&1 | grep -q "FAIL"
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

### 2026-03-17T21:10:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-515-tier-a-e2e-tests--12-shell-level-enforce.md
- **Context:** Initial task creation

### 2026-03-17T21:21:22Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
