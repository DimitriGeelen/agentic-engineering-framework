# arc_create_no_constituent_tasks

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/arc_create_no_constituent_tasks.bats`

## What It Does

T-1851 (T-NEW-4): constituent_tasks: field deprecated for new arcs.
`arc_create` no longer emits `constituent_tasks: []` for new arcs.
Legacy arcs (with the field present) continue to receive arc_tag
appends — D-Immutability preserves legacy data. Read-surfaces
(web/blueprints/arcs.py, agents/audit/audit.sh) merge legacy
constituent_tasks with the task-side arc_id: scan, so the two
populations co-exist.

## Dependencies (3)

| Target | Relationship |
|--------|-------------|
| `lib/arc.sh` | calls |
| `C-004` | tests |
| `lib/arc.sh` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-arc_create_no_constituent_tasks.yaml`*
*Last verified: 2026-05-16*
