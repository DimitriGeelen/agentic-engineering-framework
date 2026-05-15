# evolution_log_gate

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/evolution_log_gate.bats`

## What It Does

T-1718 Slice 1: Evolution-log gate
Tests the detection helper (lib/evolution_log.sh) directly. Avoids
the heavy update-task.sh harness (FD inheritance + flock issues
under bats `run`, same lesson as T-1716 audit_c006 tests).
Gate-integration tested via direct invocation of check_evolution_log
with mocked NEW_STATUS / TASK_FILE / SKIP_EVOLUTION.

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `lib/evolution_log.sh` | calls |
| `lib/evolution_log.sh` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-evolution_log_gate.yaml`*
*Last verified: 2026-05-04*
