# pre_compact_flock

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/pre_compact_flock.bats`

## What It Does

T-1476 — pre-compact.sh acquires a flock to prevent dual handover commits
when both user-level and project-level PreCompact hooks fire (OBS-023).

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `agents/context/pre-compact.sh` | calls |
| `agents/context/pre-compact.sh` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-pre_compact_flock.yaml`*
*Last verified: 2026-04-25*
