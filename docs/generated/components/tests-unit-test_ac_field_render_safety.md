# test_ac_field_render_safety

> T-3369: AC field rendering — escaped input, un-escaped output.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_ac_field_render_safety.py`

## What It Does

Tags the framework's own renderer is allowed to emit.

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [tasks](/docs/generated/web-blueprints-tasks) | calls | Flask blueprint: Tasks |
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [tasks](/docs/generated/web-blueprints-tasks) | registers | Flask blueprint: Tasks |
| [tasks](/docs/generated/web-blueprints-tasks) | uses | Flask blueprint: Tasks |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_ac_field_render_safety.yaml`*
*Last verified: 2026-09-15*
