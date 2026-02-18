---
id: T-159
name: "Test infrastructure — bats framework, test runner, fw test command"
description: >
  Install bats (Bash Automated Testing System). Create tests/ directory structure (unit/, integration/, fixtures/, mocks/). Add fw test command that runs all tests (bats + pytest). Add ShellCheck linting. Ref: T-158 inception, /tmp/T-158-bash-audit.md

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-02-18T13:30:27Z
last_update: 2026-02-18T13:59:20Z
date_finished: null
---

# T-159: Test infrastructure — bats framework, test runner, fw test command

## Context

T-158 inception GO: 44 bash scripts (10,182 LOC), zero test framework. Audit at `/tmp/T-158-bash-audit.md`.

## Acceptance Criteria

- [x] bats-core installed and functional (`bats --version`)
- [x] `tests/` directory structure: `unit/`, `integration/`, `fixtures/`
- [x] `tests/test_helper.bash` with common setup (FRAMEWORK_ROOT, temp dirs, cleanup)
- [x] At least 1 sample unit test passes (`bats tests/unit/`)
- [x] `fw test` command runs all bats tests and reports results
- [x] ShellCheck installed and functional (`shellcheck --version`)
- [x] `fw test --lint` runs ShellCheck on all framework `.sh` files

## Verification

bats --version
shellcheck --version
bats tests/unit/
fw test --lint 2>&1 | head -5
fw test 2>&1 | head -10

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

### 2026-02-18T13:30:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-159-test-infrastructure--bats-framework-test.md
- **Context:** Initial task creation

### 2026-02-18T13:59:20Z — status-update [task-update-agent]
- **Change:** horizon: now → later
