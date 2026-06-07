# test_filter_chips

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_filter_chips.py`

## What It Does

the owner chip clears owner but KEEPS horizon (per-chip isolation, not clear-all)

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [tasks](/docs/generated/web-blueprints-tasks) | calls | Flask blueprint: Tasks |
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [tasks](/docs/generated/web-blueprints-tasks) | registers | Flask blueprint: Tasks |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_filter_chips.yaml`*
*Last verified: 2026-05-24*
