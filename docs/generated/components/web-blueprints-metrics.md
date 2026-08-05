# metrics

> Flask blueprint: Metrics

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/metrics.py`

## What It Does

T-2785: initial render cap for the "Needs Attention" stale-task list.
_stale_tasks() tracks 1:1 with active-task count (260 of 317 today) and
was rendering every row unconditionally. Capped in the DOM, not via CSS —
see WORK_QUEUE_INITIAL in web/blueprints/cockpit.py for the sibling fix.

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [metrics](/docs/generated/web-templates-metrics) | renders | Watchtower UI page: Metrics |
| [context_loader](/docs/generated/web-context_loader) | calls | Centralized YAML loading for context project files (learnings, patterns, decisions, practices, concerns, directives). Replaces duplicated try/except blocks across blueprints. Uses shared.load_yaml() for error collection. |
| [subprocess_utils](/docs/generated/web-subprocess_utils) | calls | Consistent subprocess execution for git and fw commands. Provides run_git_command() and run_fw_command() with standardized timeouts, encoding, and error handling. |

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | called_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [app](/docs/generated/web-app) | registered_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-metrics.yaml`*
*Last verified: 2026-02-20*
