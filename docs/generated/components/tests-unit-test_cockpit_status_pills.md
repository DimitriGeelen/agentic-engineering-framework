# test_cockpit_status_pills

> T-2023 (arc-007 S3a): cockpit status colours use per-palette semantic tokens.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_cockpit_status_pills.py`

## What It Does

the old hardcoded badge fills are gone

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [cockpit](/docs/generated/web-templates-cockpit) | calls | Page template: Watchtower |
| [app](/docs/generated/web-app) | uses | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_cockpit_status_pills.yaml`*
*Last verified: 2026-05-24*
