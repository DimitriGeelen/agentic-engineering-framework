# lib_tasks

> Unit tests for tasks (10 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/lib_tasks.bats`

**Tags:** `tasks`, `bats`, `unit-test`

## What It Does

Unit tests for lib/tasks.sh
Tests find_task_file(), task_exists(), get_task_name()

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [tasks](/docs/generated/lib-tasks) | calls | fw task subcommand dispatcher: routes task create/update/list/verify/review to agents/task-create/ scripts. |
| [tasks](/docs/generated/lib-tasks) | tests | fw task subcommand dispatcher: routes task create/update/list/verify/review to agents/task-create/ scripts. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-lib_tasks.yaml`*
*Last verified: 2026-04-05*
