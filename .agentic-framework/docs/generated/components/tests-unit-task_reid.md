# task_reid

> Regression test — fw task reid safely renames a task's ID (handles G-052 duplicate-ID repair). Verifies atomic rename of file + id: frontmatter update, and refusal when NEW-ID already exists.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/task_reid.bats`

**Tags:** `test`, `task-create`, `reid`, `G-052`, `T-1367`

## What It Does

T-1367: fw task reid — safely rename a task's ID.
Handles the G-052 duplicate-ID repair workflow: renames the file AND updates
the `id:` frontmatter atomically. Refuses when NEW-ID already exists.

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `bin/fw` | calls |
| `.tasks/active/` | writes |

---
*Auto-generated from Component Fabric. Card: `tests-unit-task_reid.yaml`*
*Last verified: 2026-04-24*
