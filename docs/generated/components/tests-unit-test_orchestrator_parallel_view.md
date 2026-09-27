# test_orchestrator_parallel_view

> T-2342 (arc-011 M1 §5) — /orchestrator/parallel view.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_orchestrator_parallel_view.py`

## What It Does

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [orchestrator](/docs/generated/web-blueprints-orchestrator) | calls | T-1647 (W10 #2 of T-1641 Arc C) — Watchtower /orchestrator page. |
| [orchestrator](/docs/generated/web-blueprints-orchestrator) | registers | T-1647 (W10 #2 of T-1641 Arc C) — Watchtower /orchestrator page. |
| [orchestrator](/docs/generated/web-blueprints-orchestrator) | uses | T-1647 (W10 #2 of T-1641 Arc C) — Watchtower /orchestrator page. |
| [shared](/docs/generated/web-shared) | uses | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [app](/docs/generated/web-app) | uses | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_orchestrator_parallel_view.yaml`*
*Last verified: 2026-06-11*
