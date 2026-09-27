# test_api_overlay

> T-2629: /api/overlay endpoint contract — status codes + payload shape.

**Type:** script | **Subsystem:** tests | **Location:** `tests/web/test_api_overlay.py`

## What It Does

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [app](/docs/generated/web-app) | uses | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [designer](/docs/generated/web-blueprints-designer) | uses | Designer blueprint — serves the pinned Workflow Designer build (T-2521). |

---
*Auto-generated from Component Fabric. Card: `tests-web-test_api_overlay.yaml`*
*Last verified: 2026-07-27*
