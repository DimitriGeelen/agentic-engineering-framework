# test_cockpit_traceability

> T-2021: Cockpit System Health renders traceability as a percentage, not a raw dict.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_cockpit_traceability.py`

## What It Does

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [__init__](/docs/generated/web-blueprints-__init__) | calls | Flask blueprint:   Init |
| [app](/docs/generated/web-app) | uses | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [__init__](/docs/generated/web-blueprints-__init__) | uses | Flask blueprint:   Init |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_cockpit_traceability.yaml`*
*Last verified: 2026-05-24*
