# create_task_status_guard

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/create_task_status_guard.bats`

## What It Does

T-2675 — creation-side status invariant guard (companion to T-2674's owner
leg; 832 rail-316: "two independent holes with separate root causes").
create-task.sh only ever sets STATUS to the internal constants captured /
started-work, so the is_valid_status guard is a never-fires invariant today.
It exists so any future path that derives STATUS from less-trusted input
(promote/ghost origins, a --status flag) dies before write. These tests pin
(a) both live paths still write the expected valid status, (b) the guard is
present in the script, (c) the predicate itself rejects out-of-enum values.

---
*Auto-generated from Component Fabric. Card: `tests-unit-create_task_status_guard.yaml`*
*Last verified: 2026-07-29*
