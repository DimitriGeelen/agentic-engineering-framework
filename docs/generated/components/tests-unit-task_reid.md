# task_reid

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/task_reid.bats`

## What It Does

T-1367: fw task reid — safely rename a task's ID.
Handles the G-052 duplicate-ID repair workflow: renames the file AND updates
the `id:` frontmatter atomically. Refuses when NEW-ID already exists.

---
*Auto-generated from Component Fabric. Card: `tests-unit-task_reid.yaml`*
*Last verified: 2026-04-20*
