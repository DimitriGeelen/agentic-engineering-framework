# arc_membership-py

> Canonical Python helper for arc-membership scans (T-1880 / T-NEW-15).
Consolidates the union-of-`arc_id:`-frontmatter + legacy `arc:<slug>`-tag
scan that previously lived inline in three Watchtower blueprints:
web/blueprints/arcs.py, core.py, tasks.py. Companion to
lib/arc_membership.sh (which serves shell consumers).

Public API:
  scan_tasks_by_arc_membership(project_root)
      → (by_arc_id: dict[str, list[task_id]],
         by_tag:    dict[str, list[task_id]])

Origin: silent-corpus #1 (T-1874/75/76/77) and #2 (T-1879) — captured
as L-397. Each inline consumer had to be migrated independently after
the T-1850 tags-to-arc_id storage migration (162 tasks rewritten); the
consolidated helpers prevent the next storage-format migration from
leaking through nine sites again.


**Type:** library | **Subsystem:** framework-core | **Location:** `lib/arc_membership.py`

**Tags:** `arc-grooming`, `silent-corpus-prevention`

## What It Does

Frontmatter regexes — same patterns previously inline in arcs.py.

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `.tasks/active/` | reads |
| `.tasks/completed/` | reads |

## Used By (3)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/arcs.py` | calls |
| `web/blueprints/core.py` | calls |
| `web/blueprints/tasks.py` | calls |

---
*Auto-generated from Component Fabric. Card: `lib-arc_membership.yaml`*
*Last verified: 2026-05-17*
