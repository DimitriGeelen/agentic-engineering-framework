# fw_task

> Integration tests for fw task CLI — 7 tests covering create, placeholder rejection, ID increment, status update, update fail, help, list.

**Type:** test | **Subsystem:** framework-core | **Location:** `tests/integration/fw_task.bats`

**Tags:** `bats`, `integration-test`, `task`, `cli`

## What It Does

Integration tests for fw task subcommand
Tests the CLI interface for task management:
fw task create   — create a new task
fw task update   — update task status
fw task list     — list active tasks

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `bin/fw` | calls |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_task.yaml`*
*Last verified: 2026-03-29*
