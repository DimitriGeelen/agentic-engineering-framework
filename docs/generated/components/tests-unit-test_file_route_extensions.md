# test_file_route_extensions

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_file_route_extensions.py`

## What It Does

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [task_pair_acd](/docs/generated/lib-task_pair_acd) | calls | TODO: describe what this component does |
| [tasks](/docs/generated/web-blueprints-tasks) | calls | Flask blueprint: Tasks |
| [task_pair_acd-py](/docs/generated/lib-task_pair_acd-py) | calls | Task-pair §ACD gate (P-012, T-1762) — Python core. Parses inception Recommendation->Decomposition headings, verifies promised follow-up build tasks shipped via related_tasks chain. Mirror of T-1668/T-1671 arc-level §ACD gate at task-pair level (G-066 prong 2 implementation per T-1713 GO). |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_file_route_extensions.yaml`*
*Last verified: 2026-05-06*
