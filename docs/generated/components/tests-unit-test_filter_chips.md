# test_filter_chips

> T-2016 (arc-007 S4c): active-filter chips on the tasks board.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_filter_chips.py`

## What It Does

the owner chip clears owner but KEEPS horizon (per-chip isolation, not clear-all)

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [tasks](/docs/generated/web-blueprints-tasks) | calls | Flask blueprint: Tasks |
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [tasks](/docs/generated/web-blueprints-tasks) | registers | Flask blueprint: Tasks |
| [tasks](/docs/generated/web-blueprints-tasks) | uses | Flask blueprint: Tasks |
| [app](/docs/generated/web-app) | uses | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_filter_chips.yaml`*
*Last verified: 2026-05-24*
