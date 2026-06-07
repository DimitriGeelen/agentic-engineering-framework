# test_render_surface_gate

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_render_surface_gate.bats`

## What It Does

T-1766 — render-surface Human-AC gate (P-013).
Build/refactor/test tasks touching web render surfaces (templates,
blueprints, CSS/JS, web/shared.py, web/app.py) must carry at least one
[REVIEW] Human AC before --status work-completed is allowed.
Origin: T-1763, T-1764, T-1765 shipped render-surface fixes with zero
Human ACs — user caught the omission and asked for RCA + structural fix.

## Dependencies (9)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [render_surface](/docs/generated/lib-render_surface) | calls | TODO: describe what this component does |
| [update-task](/docs/generated/agents-task-create-update-task) | calls | Task Update Agent - Status transitions with auto-triggers |
| [shared](/docs/generated/web-shared) | tests | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [app](/docs/generated/web-app) | tests | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [render_surface](/docs/generated/lib-render_surface) | tests | TODO: describe what this component does |
| [update-task](/docs/generated/agents-task-create-update-task) | tests | Task Update Agent - Status transitions with auto-triggers |
| [tasks](/docs/generated/web-blueprints-tasks) | tests | Flask blueprint: Tasks |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [settings](/docs/generated/web-blueprints-settings) | tests | Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_render_surface_gate.yaml`*
*Last verified: 2026-05-16*
