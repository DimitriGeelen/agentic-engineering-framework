# test_orchestrator_workflow_coverage

> T-1799: /orchestrator surfaces Workflow coverage panel.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_orchestrator_workflow_coverage.py`

## What It Does

lib symlink so the web helper can import workflow_coverage from PROJECT_ROOT/lib

## Dependencies (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [orchestrator](/docs/generated/web-blueprints-orchestrator) | calls | T-1647 (W10 #2 of T-1641 Arc C) — Watchtower /orchestrator page. |
| [orchestrator](/docs/generated/web-blueprints-orchestrator) | registers | T-1647 (W10 #2 of T-1641 Arc C) — Watchtower /orchestrator page. |
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [orchestrator](/docs/generated/web-blueprints-orchestrator) | uses | T-1647 (W10 #2 of T-1641 Arc C) — Watchtower /orchestrator page. |
| [shared](/docs/generated/web-shared) | uses | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [app](/docs/generated/web-app) | uses | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_orchestrator_workflow_coverage.yaml`*
*Last verified: 2026-05-12*
