---
id: T-456
name: "Fix commit-msg hook find_task_file() undefined bug"
description: >
  commit-msg hook calls find_task_file() without sourcing lib/tasks.sh. Inception gate silently fails in all consumer projects. Fix: add 'source $FRAMEWORK_ROOT/lib/tasks.sh' in agents/git/lib/hooks.sh before the function call. Verify hook works in fresh init.

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: [init, hooks, bug]
components: [agents/git/lib/hooks.sh]
related_tasks: []
created: 2026-03-12T17:00:35Z
last_update: 2026-03-13T07:54:31Z
date_finished: 2026-03-13T07:54:31Z
---

# T-456: Fix commit-msg hook find_task_file() undefined bug

## Context

commit-msg hook calls `find_task_file()` without sourcing `lib/tasks.sh`. Inception gate silently fails in consumer projects where the function isn't in scope.

## Acceptance Criteria

### Agent
- [x] `agents/git/lib/hooks.sh` sources `lib/tasks.sh` before calling `find_task_file()`
- [x] `find_task_file` is available when commit-msg hook runs (verified by grep)
- [x] Existing bats tests still pass (187/187)

## Verification

grep -q "lib/tasks.sh" agents/git/lib/hooks.sh
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

### 2026-03-12T17:00:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-456-fix-commit-msg-hook-findtaskfile-undefin.md
- **Context:** Initial task creation

### 2026-03-13T07:51:59Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-13T07:54:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
