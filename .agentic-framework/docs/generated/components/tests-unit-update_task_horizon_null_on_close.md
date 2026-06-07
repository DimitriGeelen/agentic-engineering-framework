# update_task_horizon_null_on_close

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/update_task_horizon_null_on_close.bats`

## What It Does

T-2163 / arc-009 Slice 4: write-side horizon-null at full close.
update-task.sh nulls the stored `horizon:` field when moving a task into
.tasks/completed/. Partial-complete (file stays in active/) does NOT
touch horizon — that branch still renders via the stored value.
This test pins both branches in isolation so any future refactor that
regresses either direction trips the bats gate.

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [update-task](/docs/generated/agents-task-create-update-task) | calls | Task Update Agent - Status transitions with auto-triggers |
| [migrate-horizon-null-completed](/docs/generated/bin-migrate-horizon-null-completed) | calls | TODO: describe what this component does |
| [update-task](/docs/generated/agents-task-create-update-task) | tests | Task Update Agent - Status transitions with auto-triggers |
| [migrate-horizon-null-completed](/docs/generated/bin-migrate-horizon-null-completed) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-update_task_horizon_null_on_close.yaml`*
*Last verified: 2026-06-01*
