---
id: T-514
name: "E2E test framework scaffolding — runner.sh, setup/teardown, assertion helpers"
description: >
  Create tests/e2e/ directory structure with runner.sh orchestrator, lib/setup.sh (spawn TermLink session in temp dir with fw init), lib/teardown.sh (cleanup), lib/assert.sh (file_exists, exit_code_is, grep_file, yaml_field helpers). From T-513 inception build task 1.

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: [testing, termlink, D2]
components: []
related_tasks: []
created: 2026-03-17T21:10:08Z
last_update: 2026-03-17T21:14:37Z
date_finished: 2026-03-17T21:14:37Z
---

# T-514: E2E test framework scaffolding — runner.sh, setup/teardown, assertion helpers

## Context

From T-513 inception (GO). See `docs/reports/T-513-termlink-testing-methodology.md` for full design.

## Acceptance Criteria

### Agent
- [x] `tests/e2e/runner.sh` exists and is executable
- [x] `tests/e2e/lib/setup.sh` creates temp dir, spawns TermLink session
- [x] `tests/e2e/lib/teardown.sh` cleans up session and temp dir
- [x] `tests/e2e/lib/assert.sh` provides assertion helpers
- [x] Runner supports `--tier`, `--scenario`, `--json` flags
- [x] Runner produces JSON summary on `--json`
- [x] Scaffold self-tests: runner runs with no test files and exits cleanly

## Verification

test -x tests/e2e/runner.sh
test -f tests/e2e/lib/setup.sh
test -f tests/e2e/lib/teardown.sh
test -f tests/e2e/lib/assert.sh
bash tests/e2e/runner.sh --tier a --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'results' in d"

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

### 2026-03-17T21:10:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-514-e2e-test-framework-scaffolding--runnersh.md
- **Context:** Initial task creation

### 2026-03-17T21:14:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
