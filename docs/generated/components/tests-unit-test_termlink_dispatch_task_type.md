# test_termlink_dispatch_task_type

> Unit tests for fw termlink dispatch/spawn orchestrator-substrate wiring (T-1643/W1-W4) — pins _derive_task_type, _resolve_dispatch_model fallback chain, --task-type flag handlers in cmd_spawn/cmd_dispatch, and meta.json schema (task_type/model_used/fallback_used).

**Type:** script | **Subsystem:** testing | **Location:** `tests/unit/test_termlink_dispatch_task_type.py`

**Tags:** `termlink`, `orchestrator`, `regression`, `t-1643`

## What It Does

Source termlink.sh inside a subshell that ignores its trailing
"wrong-call" exit; we only want the function definitions.

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `agents/termlink/termlink.sh` | calls |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_termlink_dispatch_task_type.yaml`*
*Last verified: 2026-05-01*
