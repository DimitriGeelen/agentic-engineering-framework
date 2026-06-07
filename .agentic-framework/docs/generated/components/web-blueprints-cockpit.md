# cockpit

> Flask blueprint: Cockpit

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/cockpit.py`

## What It Does

web/blueprints/cockpit.py

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [subprocess_utils](/docs/generated/web-subprocess_utils) | calls | Consistent subprocess execution for git and fw commands. Provides run_git_command() and run_fw_command() with standardized timeouts, encoding, and error handling. |
| [tasks](/docs/generated/web-blueprints-tasks) | calls | Flask blueprint: Tasks |
| [tasks](/docs/generated/web-blueprints-tasks) | registers | Flask blueprint: Tasks |

## Used By (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | called_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [app](/docs/generated/web-app) | registered_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [core](/docs/generated/web-blueprints-core) | called_by | Flask blueprint: Core |
| [core](/docs/generated/web-blueprints-core) | registered_by | Flask blueprint: Core |
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [test_api_scan](/docs/generated/tests-playwright-test_api_scan) | called_by | Playwright tests for scan API endpoints (T-1029). |
| [test_api_scan_actions](/docs/generated/tests-playwright-test_api_scan_actions) | called_by | Playwright tests for scan action endpoints (T-1041). |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-cockpit.yaml`*
*Last verified: 2026-02-20*
