# pre_compact_timewindow_dedup

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/pre_compact_timewindow_dedup.bats`

## What It Does

T-1478 — pre-compact.sh layers a time-window dedup on top of flock to
catch SEQUENTIAL dual-fires that flock alone cannot stop. When both
user-level and project-level PreCompact hooks register, /compact may
invoke them sequentially (A finishes before B starts). Without time-window
dedup, B will run a fresh handover and produce duplicate content.

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `agents/context/pre-compact.sh` | calls |
| `agents/context/pre-compact.sh` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-pre_compact_timewindow_dedup.yaml`*
*Last verified: 2026-04-25*
