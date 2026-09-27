# test_designer_overlay

> T-2630: /designer/overlay wrapper page + landing overlay-link contract.

**Type:** script | **Subsystem:** tests | **Location:** `tests/web/test_designer_overlay.py`

## What It Does

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [app](/docs/generated/web-app) | uses | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [designer](/docs/generated/web-blueprints-designer) | uses | Designer blueprint — serves the pinned Workflow Designer build (T-2521). |
| [designer_api](/docs/generated/web-blueprints-designer_api) | uses | Designer gallery-server API (T-2529) — the ``/api/*`` endpoints that 832's shipped 0.2.0 Workflow Designer client already calls. |

---
*Auto-generated from Component Fabric. Card: `tests-web-test_designer_overlay.yaml`*
*Last verified: 2026-07-27*
