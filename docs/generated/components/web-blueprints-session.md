# session

> Flask blueprint: Session

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/session.py`

## What It Does

Helpers

### Framework Reference

When you need to propose a new free driver, an arc-scoped driver, or sharpen an existing one, the canonical workflow lives in **`policy/prompts/`** — NOT inlined into this CLAUDE.md.

| Bundle file | When to reach for it |
|-------------|----------------------|
| `policy/prompts/bvp-driver-session.md` | **Always start here.** Keystone. Three workflows (A=batch-propose, B=discover+sharpen, C=sharpen named topic). Entry/exit conditions, outputs, init refusal, degraded mode. |
| `policy/prompts/artefact-template.md` | When writing the research artefact (`docs/reports/T-XXXX-bvp-driver-*.md`). YAM

*(truncated — see CLAUDE.md for full section)*

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [subprocess_utils](/docs/generated/web-subprocess_utils) | calls | Consistent subprocess execution for git and fw commands. Provides run_git_command() and run_fw_command() with standardized timeouts, encoding, and error handling. |
| [shared](/docs/generated/web-shared) | uses | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [subprocess_utils](/docs/generated/web-subprocess_utils) | uses | Consistent subprocess execution for git and fw commands. Provides run_git_command() and run_fw_command() with standardized timeouts, encoding, and error handling. |

## Used By (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | called_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [app](/docs/generated/web-app) | registered_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [test_api_context_capture](/docs/generated/tests-playwright-test_api_context_capture) | called_by | Playwright tests for context capture API endpoints (T-1030). |
| [test_api_healing](/docs/generated/tests-playwright-test_api_healing) | called_by | Playwright tests for /api/healing/<task_id> endpoint (T-1026). |
| [test_api_session_init](/docs/generated/tests-playwright-test_api_session_init) | called_by | Playwright tests for session init API (T-1029). |
| [__init__](/docs/generated/web-blueprints-__init__) | uses_by | Flask blueprint:   Init |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-session.yaml`*
*Last verified: 2026-02-20*
