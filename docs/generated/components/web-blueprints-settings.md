# settings

> Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state.

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/settings.py`

## What It Does

── arc-007 S1 (T-1988): appearance presets + per-user persistence ──────────
The 6 named presets from the arc headline mechanic. Each is a curated combo
over the S0 foundation axes (T-1991). Axis values MUST match foundations.css.

## Dependencies (3)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | imports |
| `web/shared.py` | calls |
| `web/templates/settings.html` | renders |

## Used By (4)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/__init__.py` | called_by |
| `web/blueprints/__init__.py` | registered_by |
| `tests/playwright/test_settings_models.py` | called_by |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-settings.yaml`*
*Last verified: 2026-03-09*
