# test_nav_layout_polish

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_nav_layout_polish.py`

## What It Does

── F4a: presets no longer carry a nav layout ──────────────────────────────

## Dependencies (9)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [settings](/docs/generated/web-blueprints-settings) | calls | Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state. |
| [__init__](/docs/generated/web-blueprints-__init__) | calls | Flask blueprint:   Init |
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [settings](/docs/generated/web-blueprints-settings) | registers | Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state. |
| [base](/docs/generated/web-templates-base) | calls | Template: {{ page_title \| default("Watchtower") }} — Agentic Engineering Framework |
| [appearance](/docs/generated/web-templates-appearance) | calls | TODO: describe what this component does |
| [settings](/docs/generated/web-blueprints-settings) | uses | Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state. |
| [__init__](/docs/generated/web-blueprints-__init__) | uses | Flask blueprint:   Init |
| [app](/docs/generated/web-app) | uses | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_nav_layout_polish.yaml`*
*Last verified: 2026-05-24*
