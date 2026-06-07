# session

> Flask blueprint: Session

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/session.py`

## What It Does

Helpers

### Framework Reference

**Before beginning any work:**
1. Initialize context: `fw context init`
2. Read `.context/handovers/LATEST.md` to understand current state
3. Review the "Suggested First Action" section
4. Set focus: `fw context focus T-XXX`
5. Run `fw metrics` to see project status
6. If handover feedback section exists, fill it in

**Before ANY implementation (even if a skill says "start now"):**
1. Verify a task exists for the work: `fw work-on "name" --type build` or `fw work-on T-XXX`
2. Confirm focus is set in `.context/working/focus.yaml`
3. THEN proceed with implementation

*(truncated — see CLAUDE.md for full section)*

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [subprocess_utils](/docs/generated/web-subprocess_utils) | calls | Consistent subprocess execution for git and fw commands. Provides run_git_command() and run_fw_command() with standardized timeouts, encoding, and error handling. |

## Used By (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | called_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [app](/docs/generated/web-app) | registered_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [test_api_context_capture](/docs/generated/tests-playwright-test_api_context_capture) | called_by | Playwright tests for context capture API endpoints (T-1030). |
| [test_api_healing](/docs/generated/tests-playwright-test_api_healing) | called_by | Playwright tests for /api/healing/<task_id> endpoint (T-1026). |
| [test_api_session_init](/docs/generated/tests-playwright-test_api_session_init) | called_by | Playwright tests for session init API (T-1029). |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-session.yaml`*
*Last verified: 2026-02-20*
