# inception_defer_park

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/inception_defer_park.bats`

## What It Does

T-1865 — DEFER inception decisions park the task instead of leaving it
stuck at status=started-work / horizon=now. Two surfaces:
1. do_inception_sweep recovers existing DEFER limbo tasks
2. (Decide-defer path is interactive / Tier-0-gated; covered indirectly
by sweep + manual smoke against this repo's 6 limbo tasks.)

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `bin/fw` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-inception_defer_park.yaml`*
*Last verified: 2026-05-15*
