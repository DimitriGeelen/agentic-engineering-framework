# cron

> Watchtower cron blueprint: cron job status display — shows registered jobs, schedule, last run, active/paused state.

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/cron.py`

## What It Does

Cron files managed by the framework

## Dependencies (3)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | calls |
| `web/templates/cron.html` | renders |
| `bin/fw` | calls |

## Used By (4)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/__init__.py` | called_by |
| `web/blueprints/__init__.py` | registered_by |
| `tests/playwright/test_api_cron_jobs.py` | called_by |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-cron.yaml`*
*Last verified: 2026-03-12*
