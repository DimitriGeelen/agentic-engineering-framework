# arc_membership_dual_id

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/arc_membership_dual_id.bats`

## What It Does

tests/unit/arc_membership_dual_id.bats — T-1913
Pins the slug↔NNN union behaviour in arc_tasks_for().
Without this fix:
- `arc_tasks_for "<slug>"` returns only tasks with `arc_id: <slug>`
- `arc_tasks_for "<NNN>"` returns only tasks with `arc_id: <NNN>`
- Mixed-form corpora (the normal case post-T-1848 sequential IDs) get
a silent undercount.
B-1 from the arc-005 critical re-audit (2026-05-18 session): the arc-grooming
arc had 32 slug-form tasks + 3 NNN-form tasks = 35 total constituents, but
`fw arc show arc-grooming` returned 32 while Watchtower returned 35.

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `lib/arc_membership.sh` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-arc_membership_dual_id.yaml`*
*Last verified: 2026-05-18*
