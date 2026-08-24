# t3030_two_writer_guard

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3030_two_writer_guard.bats`

## What It Does

T-3030 / G-083: the autonomous dispatch loop and an interactive session share
one working tree. These tests pin the guard that separates them, and the
provenance record that makes a worker's writes attributable afterwards.
The case being regressed is not hypothetical. On 2026-08-16 a worker was
dispatched onto T-3028 four seconds after a tick that read `current_task:
null` — nulled by the close path itself (update-task.sh:2044-2055) on a
completion that was itself wrong — while the interactive session was
mid-reconciliation on that task. Both wrote agents/task-create/update-task.sh.
So the tests below deliberately assert against a NULL focus. Anything that
passes only because focus happens to name the task is re-testing the guard

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [resolver](/docs/generated/lib-resolver) | calls | TODO: describe what this component does |
| [update-task](/docs/generated/agents-task-create-update-task) | tests | Task Update Agent - Status transitions with auto-triggers |
| [resolver](/docs/generated/lib-resolver) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3030_two_writer_guard.yaml`*
*Last verified: 2026-08-16*
