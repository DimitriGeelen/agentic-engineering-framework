# settings

> Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state.

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/settings.py`

## What It Does

── arc-007 S1 (T-1988): appearance presets + per-user persistence ──────────
The 6 named presets from the arc headline mechanic. Each is a curated combo
over the S0 foundation axes (T-1991). Axis values MUST match foundations.css.

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | imports | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [settings](/docs/generated/web-templates-settings) | renders | Full page template: settings — hook configuration, notification state, framework paths. |
| [appearance](/docs/generated/web-templates-appearance) | renders | TODO: describe what this component does |

## Used By (9)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [test_settings_models](/docs/generated/tests-playwright-test_settings_models) | called_by | Playwright tests for settings models endpoint (T-1025). |
| [test_nav_layout_polish](/docs/generated/tests-unit-test_nav_layout_polish) | called_by | TODO: describe what this component does |
| [test_nav_layout_polish](/docs/generated/tests-unit-test_nav_layout_polish) | registered_by | TODO: describe what this component does |
| [shared](/docs/generated/web-shared) | called_by | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [shared](/docs/generated/web-shared) | registered_by | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [test_render_surface_gate](/docs/generated/tests-unit-test_render_surface_gate) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-settings.yaml`*
*Last verified: 2026-03-09*
