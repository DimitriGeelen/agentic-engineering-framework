# test_nav_subsections

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_nav_subsections.py`

## What It Does

every leaf is a (label, endpoint, icon) 3-tuple with a non-empty endpoint string

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_nav_subsections.yaml`*
*Last verified: 2026-05-23*
