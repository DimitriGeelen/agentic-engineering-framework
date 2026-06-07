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

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [arc_membership-sh](/docs/generated/lib-arc_membership-sh) | tests | Canonical shell helper for arc-membership scans (T-1880 / T-NEW-15). Consolidates the union-of-`arc_id:`-frontmatter + legacy `arc:<slug>`-tag scan that previously lived inline in three shell consumers: lib/arc.sh, agents/handover/handover.sh, lib/evolution_log.sh. Companion to lib/arc_membership.py (which serves the Python/Flask side).  Public API (PROJECT_ROOT must be set):   arc_tasks_with_arc_id <slug>   → T-IDs whose `arc_id:` matches slug   arc_tasks_with_tag <tag>       → T-IDs whose `tags:` includes tag  Origin: silent-corpus #1 (T-1874/75/76/77) and #2 (T-1879) — captured as L-397. Each inline consumer had to be migrated independently after the T-1850 tags-to-arc_id storage migration; consolidation prevents the next storage-format migration from leaking through nine sites again. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-arc_membership_dual_id.yaml`*
*Last verified: 2026-05-18*
