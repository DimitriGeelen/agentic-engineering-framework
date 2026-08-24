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

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| `.tasks/active/` | reads | — |
| `.tasks/completed/` | reads | — |
| [arcs](/docs/generated/web-blueprints-arcs) | calls | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [tasks](/docs/generated/web-blueprints-tasks) | calls | Flask blueprint: Tasks |

## Used By (11)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [arcs](/docs/generated/web-blueprints-arcs) | calls | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [core](/docs/generated/web-blueprints-core) | calls | Flask blueprint: Core |
| [tasks](/docs/generated/web-blueprints-tasks) | calls | Flask blueprint: Tasks |
| [test_arc_membership_shared](/docs/generated/tests-unit-test_arc_membership_shared) | called_by | TODO: describe what this component does |
| [arcs](/docs/generated/web-blueprints-arcs) | called_by | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [core](/docs/generated/web-blueprints-core) | called_by | Flask blueprint: Core |
| [tasks](/docs/generated/web-blueprints-tasks) | called_by | Flask blueprint: Tasks |
| [test_arc_membership_shared](/docs/generated/tests-unit-test_arc_membership_shared) | uses_by | TODO: describe what this component does |
| [arcs](/docs/generated/web-blueprints-arcs) | uses_by | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [core](/docs/generated/web-blueprints-core) | uses_by | Flask blueprint: Core |
| [tasks](/docs/generated/web-blueprints-tasks) | uses_by | Flask blueprint: Tasks |

---
*Auto-generated from Component Fabric. Card: `lib-arc_membership.yaml`*
*Last verified: 2026-05-17*
