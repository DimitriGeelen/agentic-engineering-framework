# test_cron_generate_shape

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_cron_generate_shape.bats`

## What It Does

T-1769 — Pin the shape of `fw cron generate` output. Origin: T-1720 found
that the generator silently produced unrunnable lines (no cwd for `python3
-m lib.X` invocations; stderr swallowed by `2>/dev/null`). Reviewer audit
was effectively dead for 9 days. Generator shape is now load-bearing —
this fixture pins it.

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `tools/escalation-scan-v0.5.py` | tests |
| `bin/fw` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_cron_generate_shape.yaml`*
*Last verified: 2026-05-06*
