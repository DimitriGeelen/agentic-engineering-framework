# test_kanban_drag

> T-2019 (arc-007 S4d): drag-to-reorder kanban — cross-column status change.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_kanban_drag.py`

## What It Does

the two attributes live on the same card element

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [kanban-drag](/docs/generated/web-static-kanban-drag) | calls | Drag-to-reorder kanban (cross-column status change) — arc-007 S4d (T-2019). |
| [app](/docs/generated/web-app) | uses | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_kanban_drag.yaml`*
*Last verified: 2026-05-24*
