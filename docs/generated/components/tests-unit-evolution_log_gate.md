# evolution_log_gate

> T-1718 Slice 1: Evolution-log gate

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/evolution_log_gate.bats`

## What It Does

T-1718 Slice 1: Evolution-log gate
Tests the detection helper (lib/evolution_log.sh) directly. Avoids
the heavy update-task.sh harness (FD inheritance + flock issues
under bats `run`, same lesson as T-1716 audit_c006 tests).
Gate-integration tested via direct invocation of check_evolution_log
with mocked NEW_STATUS / TASK_FILE / SKIP_EVOLUTION.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [evolution_log](/docs/generated/lib-evolution_log) | calls | Detection helper for the T-1717 Q4 rigidity-vs-evolution pattern (T-1718 implementation). Mirrors lib/inception_recommendation.sh (T-1716) shape exactly: detection helper extracted so it can be tested without spinning up update-task.sh. |
| [evolution_log](/docs/generated/lib-evolution_log) | tests | Detection helper for the T-1717 Q4 rigidity-vs-evolution pattern (T-1718 implementation). Mirrors lib/inception_recommendation.sh (T-1716) shape exactly: detection helper extracted so it can be tested without spinning up update-task.sh. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-evolution_log_gate.yaml`*
*Last verified: 2026-05-04*
