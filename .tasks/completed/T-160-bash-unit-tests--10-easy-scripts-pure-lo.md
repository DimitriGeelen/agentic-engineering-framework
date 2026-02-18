---
id: T-160
name: "Bash unit tests — 10 EASY scripts (pure logic, no I/O)"
description: >
  Write bats unit tests for the 10 EASY-rated scripts: context.sh, log.sh, healing.sh, focus.sh, common.sh, bus-handler.sh, status.sh (git), suggest.sh, pre-compact.sh, diagnose.sh. Target: 569 lines covered, 100% of pure logic. Ref: T-158, /tmp/T-158-bash-audit.md

status: work-completed
workflow_type: test
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-02-18T13:30:41Z
last_update: 2026-02-18T15:16:45Z
date_finished: 2026-02-18T15:16:45Z
---

# T-160: Bash unit tests — 10 EASY scripts (pure logic, no I/O)

## Context

T-159 infrastructure complete. 10 EASY-rated scripts from T-158 audit: pure logic, no I/O, stateless.

## Acceptance Criteria

- [x] Unit tests for `agents/git/lib/common.sh` (extract_task_id, task_exists, get_task_name) — 10 tests
- [x] Unit tests for `agents/git/lib/log.sh` (log filtering/formatting) — 14 tests
- [x] Unit tests for `agents/context/lib/focus.sh` (focus getter/setter) — 15 tests
- [x] Unit tests for `agents/healing/lib/suggest.sh` (pattern suggestions) — 9 tests
- [x] Unit tests for `agents/healing/lib/diagnose.sh` (classification logic) — 36 tests
- [x] All tests pass: `bats tests/unit/` — 84/84
- [x] Minimum 50 test cases across all files — 84 total

## Verification

bats tests/unit/

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

### 2026-02-18T13:30:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-160-bash-unit-tests--10-easy-scripts-pure-lo.md
- **Context:** Initial task creation

### 2026-02-18T15:16:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
