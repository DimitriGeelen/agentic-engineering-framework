# test_nav_layout_polish

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_nav_layout_polish.py`

## What It Does

── F4a: presets no longer carry a nav layout ──────────────────────────────

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [settings](/docs/generated/web-blueprints-settings) | calls | Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state. |
| [__init__](/docs/generated/web-blueprints-__init__) | calls | Flask blueprint:   Init |
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [settings](/docs/generated/web-blueprints-settings) | registers | Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_nav_layout_polish.yaml`*
*Last verified: 2026-05-24*
