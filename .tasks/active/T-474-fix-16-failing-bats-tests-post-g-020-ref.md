---
id: T-474
name: "Fix 16 failing bats tests (post-G-020 refactoring)"
description: >
  Fix the 16 failing tests across check_active_task.bats and unit tests. Failures are due to recent G-020 refactoring (check-active-task.sh now has placeholder AC detection). Update test expectations to match new gate behavior.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [testing, D2]
components: []
related_tasks: []
created: 2026-03-12T21:30:55Z
last_update: 2026-03-12T21:30:55Z
date_finished: null
---

# T-474: Fix 16 failing bats tests (post-G-020 refactoring)

## Context

Continuation of T-473 (GO). 22 tests failing across 4 test files due to: G-020 refactoring (check-active-task.sh), missing function sources (focus.sh, suggest.sh), removed function (score_pattern).

## Acceptance Criteria

### Agent
- [x] All bats tests pass: `bats tests/integration/ tests/unit/` exits 0 (151/151)
- [x] check_active_task.bats: B-005 settings.json test updated, task file fixtures added for G-013/G-020
- [x] context_focus.bats: lib/tasks.sh + lib/compat.sh sourced for find_task_file/get_task_name/_sed_i
- [x] healing_diagnose.bats: removed 10 score_pattern tests (function no longer exists)
- [x] healing_suggest.bats: lib/yaml.sh sourced for get_yaml_field
- [x] git_common.bats: lib/tasks.sh sourced, quote-stripping assertion fixed

## Verification

bats tests/integration/ tests/unit/

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

### 2026-03-12T21:30:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-474-fix-16-failing-bats-tests-post-g-020-ref.md
- **Context:** Initial task creation
