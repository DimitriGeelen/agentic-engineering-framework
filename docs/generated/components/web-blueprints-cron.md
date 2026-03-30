# cron

> Watchtower cron blueprint: cron job status display — shows registered jobs, schedule, last run, active/paused state.

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/cron.py`

## What It Does

Cron files managed by the framework

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | calls |
| `web/templates/cron.html` | renders |

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/__init__.py` | called_by |
| `web/blueprints/__init__.py` | registered_by |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-cron.yaml`*
*Last verified: 2026-03-12*
