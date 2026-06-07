# cron

> Watchtower cron blueprint: cron job status display — shows registered jobs, schedule, last run, active/paused state.

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/cron.py`

## What It Does

Cron files managed by the framework

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [cron](/docs/generated/web-templates-cron) | renders | Full page template: cron status — job table with schedule, last run, status indicators. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [test_api_cron_jobs](/docs/generated/tests-playwright-test_api_cron_jobs) | called_by | Playwright tests for cron job API endpoints (T-1033). |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-cron.yaml`*
*Last verified: 2026-03-12*
