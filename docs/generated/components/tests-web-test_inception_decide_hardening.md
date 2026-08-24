# test_inception_decide_hardening

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/web/test_inception_decide_hardening.py`

## What It Does

{task_id}: hardening

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [app](/docs/generated/web-app) | uses | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [shared](/docs/generated/web-shared) | uses | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [subprocess_utils](/docs/generated/web-subprocess_utils) | uses | Consistent subprocess execution for git and fw commands. Provides run_git_command() and run_fw_command() with standardized timeouts, encoding, and error handling. |
| [inception](/docs/generated/web-blueprints-inception) | uses | Blueprint 'inception' — routes: /inception |

---
*Auto-generated from Component Fabric. Card: `tests-web-test_inception_decide_hardening.yaml`*
*Last verified: 2026-04-25*
