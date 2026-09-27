# test_arcs_kanban

> T-1904: /arcs kanban — 4-column lifecycle layout replacing T-1853 tabs.

**Type:** script | **Subsystem:** tests-playwright | **Location:** `tests/playwright/test_arcs_kanban.py`

## What It Does

Order MUST match _LIFECYCLE_STATES in web/blueprints/arcs.py

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [arcs](/docs/generated/web-blueprints-arcs) | calls | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |

---
*Auto-generated from Component Fabric. Card: `tests-playwright-test_arcs_kanban.yaml`*
*Last verified: 2026-05-18*
