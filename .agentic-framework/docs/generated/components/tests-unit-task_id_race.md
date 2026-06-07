# task_id_race

> Regression test — concurrent fw work-on invocations must allocate distinct task IDs. Prior bug: generate_id() read max_id then (later) wrote the file; N parallel invocations all observed the same max_id and wrote T-${max+1}. Fix: keylock around read-compute-write sequence.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/task_id_race.bats`

**Tags:** `test`, `task-create`, `race-condition`, `T-1279`

## What It Does

T-1279: Concurrent fw work-on must allocate distinct task IDs.
Prior bug: generate_id() read max_id, then (later) wrote the file. N parallel
invocations all observed the same max_id and all wrote T-${max+1}.
Fix: keylock around the read-compute-write sequence.

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [create-task](/docs/generated/agents-task-create-create-task) | calls | Task Creation Agent - Mechanical Operations |
| [create-task](/docs/generated/agents-task-create-create-task) | tests | Task Creation Agent - Mechanical Operations |
| [keylock](/docs/generated/lib-keylock) | tests | Advisory file locking: task-level lock files in .context/locks/ to prevent concurrent task modifications. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-task_id_race.yaml`*
*Last verified: 2026-04-24*
