# test_api_version_latest

> T-2624: /api/version bare-id resolution — `?id=` alone serves the latest version.

**Type:** script | **Subsystem:** tests | **Location:** `tests/web/test_api_version_latest.py`

## What It Does

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [app](/docs/generated/web-app) | uses | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [designer_api](/docs/generated/web-blueprints-designer_api) | uses | Designer gallery-server API (T-2529) — the ``/api/*`` endpoints that 832's shipped 0.2.0 Workflow Designer client already calls. |

---
*Auto-generated from Component Fabric. Card: `tests-web-test_api_version_latest.yaml`*
*Last verified: 2026-07-27*
