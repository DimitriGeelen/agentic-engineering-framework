# skip_ac_partial_complete

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/skip_ac_partial_complete.bats`

## What It Does

T-1559 — Regression: --skip-acceptance-criteria must bypass the AC check on
the partial-complete recheck branch, not just the initial transition. Origin:
pickup P-016 from 003-NTB-ATC-Plugin (T-225, C-018) — 20 tasks closed via
manual checkbox-editing workaround in a single session. The auth flag is the
marker of authorization; the file state is the artifact.

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `agents/task-create/update-task.sh` | calls |
| `agents/task-create/update-task.sh` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-skip_ac_partial_complete.yaml`*
*Last verified: 2026-04-27*
