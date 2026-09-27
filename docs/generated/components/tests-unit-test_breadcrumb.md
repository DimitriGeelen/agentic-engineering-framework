# test_breadcrumb

> T-2009 (arc-007 S2b): path-derived breadcrumb guard.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_breadcrumb.py`

## What It Does

last crumb (current page) is unlinked

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [app](/docs/generated/web-app) | uses | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [shared](/docs/generated/web-shared) | uses | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_breadcrumb.yaml`*
*Last verified: 2026-05-23*
