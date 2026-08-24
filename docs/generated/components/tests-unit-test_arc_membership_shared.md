# test_arc_membership_shared

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_arc_membership_shared.py`

## What It Does

1: legacy-tag-only

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [arc_membership-py](/docs/generated/lib-arc_membership) | calls | Canonical Python helper for arc-membership scans (T-1880 / T-NEW-15). Consolidates the union-of-`arc_id:`-frontmatter + legacy `arc:<slug>`-tag scan that previously lived inline in three Watchtower blueprints: web/blueprints/arcs.py, core.py, tasks.py. Companion to lib/arc_membership.sh (which serves shell consumers).  Public API:   scan_tasks_by_arc_membership(project_root)       → (by_arc_id: dict[str, list[task_id]],          by_tag:    dict[str, list[task_id]])  Origin: silent-corpus #1 (T-1874/75/76/77) and #2 (T-1879) — captured as L-397. Each inline consumer had to be migrated independently after the T-1850 tags-to-arc_id storage migration (162 tasks rewritten); the consolidated helpers prevent the next storage-format migration from leaking through nine sites again. |
| [arc_membership-py](/docs/generated/lib-arc_membership) | uses | Canonical Python helper for arc-membership scans (T-1880 / T-NEW-15). Consolidates the union-of-`arc_id:`-frontmatter + legacy `arc:<slug>`-tag scan that previously lived inline in three Watchtower blueprints: web/blueprints/arcs.py, core.py, tasks.py. Companion to lib/arc_membership.sh (which serves shell consumers).  Public API:   scan_tasks_by_arc_membership(project_root)       → (by_arc_id: dict[str, list[task_id]],          by_tag:    dict[str, list[task_id]])  Origin: silent-corpus #1 (T-1874/75/76/77) and #2 (T-1879) — captured as L-397. Each inline consumer had to be migrated independently after the T-1850 tags-to-arc_id storage migration (162 tasks rewritten); the consolidated helpers prevent the next storage-format migration from leaking through nine sites again. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_arc_membership_shared.yaml`*
*Last verified: 2026-05-17*
