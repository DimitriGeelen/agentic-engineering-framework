# quality

> Flask blueprint: Quality

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/quality.py`

## What It Does

_load_latest_audit moved to web.shared.load_latest_audit (T-431/A7)

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [quality](/docs/generated/web-templates-quality) | renders | Watchtower UI page: Quality |
| [subprocess_utils](/docs/generated/web-subprocess_utils) | calls | Consistent subprocess execution for git and fw commands. Provides run_git_command() and run_fw_command() with standardized timeouts, encoding, and error handling. |
| [context_loader](/docs/generated/web-context_loader) | calls | Centralized YAML loading for context project files (learnings, patterns, decisions, practices, concerns, directives). Replaces duplicated try/except blocks across blueprints. Uses shared.load_yaml() for error collection. |

## Used By (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | called_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [app](/docs/generated/web-app) | registered_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [test_api_quality](/docs/generated/tests-playwright-test_api_quality) | called_by | Playwright tests for quality API endpoints (T-1030). |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-quality.yaml`*
*Last verified: 2026-02-20*
