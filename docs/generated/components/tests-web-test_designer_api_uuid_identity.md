# test_designer_api_uuid_identity

> T-2573 (T-2571 S1): immutable workflow uuid in the designer store.

**Type:** script | **Subsystem:** tests | **Location:** `tests/web/test_designer_api_uuid_identity.py`

## What It Does

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [app](/docs/generated/web-app) | uses | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [designer_api](/docs/generated/web-blueprints-designer_api) | uses | Designer gallery-server API (T-2529) — the ``/api/*`` endpoints that 832's shipped 0.2.0 Workflow Designer client already calls. |

---
*Auto-generated from Component Fabric. Card: `tests-web-test_designer_api_uuid_identity.yaml`*
*Last verified: 2026-07-20*
