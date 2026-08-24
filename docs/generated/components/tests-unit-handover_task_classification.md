# handover_task_classification

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/handover_task_classification.bats`

## What It Does

T-3027 (OBS-276): `tasks_active:` must mean active.
The field was built by listing `.tasks/active/*.md` and reading `id:`, never
`status:`. But `.tasks/active/` is a directory, not a state — it holds captured,
started-work, issues, and partial-complete (work-completed, awaiting a human)
side by side. The field therefore asserted ~119 tasks were active when ~37 were
in flight.
These tests build a real `.tasks/active/` with one task per status and assert
each lands in exactly one bucket. The union check is the important one: it is
what stops a future "just filter it" change from silently dropping the parked
and awaiting-review tasks on the floor.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [handover](/docs/generated/agents-handover-handover) | tests | Handover Agent - Mechanical Operations |

---
*Auto-generated from Component Fabric. Card: `tests-unit-handover_task_classification.yaml`*
*Last verified: 2026-08-16*
