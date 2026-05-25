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

## Dependencies (8)

| Target | Relationship |
|--------|-------------|
| `lib/render_surface.sh` | calls |
| `agents/task-create/update-task.sh` | calls |
| `web/shared.py` | tests |
| `web/app.py` | tests |
| `lib/render_surface.sh` | tests |
| `agents/task-create/update-task.sh` | tests |
| `web/blueprints/tasks.py` | tests |
| `bin/fw` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_render_surface_gate.yaml`*
*Last verified: 2026-05-16*
