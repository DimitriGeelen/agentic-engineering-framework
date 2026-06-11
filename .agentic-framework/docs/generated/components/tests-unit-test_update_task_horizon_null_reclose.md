# test_update_task_horizon_null_reclose

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_update_task_horizon_null_reclose.bats`

## What It Does

T-2300: re-close-path leg-gap regression test.
T-2163 nulled horizon at close-time, but only INSIDE the move-conditional
in agents/task-create/update-task.sh. The re-close path (file already in
.tasks/completed/ with non-completed status — the L-461 stale-PC class)
bypassed the move, and therefore the horizon-null mutation too.
Result: 8 tasks in completed/ kept `horizon: now` and tripped CTL-030
(T-2168/T-2180/T-2182/T-2196/T-2201/T-2203/T-2204/T-2248).
T-2300 lifts the mutation out of the move-conditional. This test pins the
re-close path so any future refactor that re-nests it trips the gate.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [update-task](/docs/generated/agents-task-create-update-task) | calls | Task Update Agent - Status transitions with auto-triggers |
| [update-task](/docs/generated/agents-task-create-update-task) | tests | Task Update Agent - Status transitions with auto-triggers |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_update_task_horizon_null_reclose.yaml`*
*Last verified: 2026-06-10*
