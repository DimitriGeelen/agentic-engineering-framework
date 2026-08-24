# test_cockpit_activity

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_cockpit_activity.py`

## What It Does

chrome-less fragment (no <html>/<body> wrapper)

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [__init__](/docs/generated/web-blueprints-__init__) | calls | Flask blueprint:   Init |
| [app](/docs/generated/web-app) | uses | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [__init__](/docs/generated/web-blueprints-__init__) | uses | Flask blueprint:   Init |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_cockpit_activity.yaml`*
*Last verified: 2026-05-24*
