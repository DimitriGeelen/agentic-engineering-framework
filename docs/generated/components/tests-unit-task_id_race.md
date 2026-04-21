# task_id_race

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/task_id_race.bats`

## What It Does

T-1279: Concurrent fw work-on must allocate distinct task IDs.
Prior bug: generate_id() read max_id, then (later) wrote the file. N parallel
invocations all observed the same max_id and all wrote T-${max+1}.
Fix: keylock around the read-compute-write sequence.

---
*Auto-generated from Component Fabric. Card: `tests-unit-task_id_race.yaml`*
*Last verified: 2026-04-20*
