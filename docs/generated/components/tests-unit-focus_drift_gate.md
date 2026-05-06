# focus_drift_gate

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/focus_drift_gate.bats`

## What It Does

T-1730: Focus-target drift gate — unit tests
Closes G1 (Bash matcher gap) + G3 (focus-target drift uninspected) from
T-1729 meta-RCA. Tests the Bash branch of agents/context/check-active-task.sh.
Tests are isolated: each one creates a temporary PROJECT_ROOT with a
.context/working/focus.yaml so we can simulate any focus state without
polluting the real project.

## Dependencies (5)

| Target | Relationship |
|--------|-------------|
| `agents/context/check-active-task.sh` | calls |
| `lib/init.sh` | calls |
| `agents/context/check-active-task.sh` | tests |
| `lib/init.sh` | tests |
| `bin/fw` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-focus_drift_gate.yaml`*
*Last verified: 2026-05-05*
