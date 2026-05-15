# test_task_pair_acd_parser

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_task_pair_acd_parser.bats`

## What It Does

T-1762: task-pair §ACD gate (P-012) — parser spike (T-1713 Spike 1)
Tests for lib/task_pair_acd.{sh,py}::extract_deliverables
Pins the parser contract:
- T-1442 GO with explicit `**Decomposition (follow-up build tasks after GO):**`
block → returns 8 items (B1..B8)
- T-1713 GO without Decomposition heading → returns empty (gate no-op)
- T-1715 GO without Decomposition heading → returns empty (gate no-op)
- NO-GO inception → exit 3
- Missing Recommendation block → exit 2

## Dependencies (4)

| Target | Relationship |
|--------|-------------|
| `lib/task_pair_acd.sh` | calls |
| `lib/task_pair_acd.py` | calls |
| `lib/task_pair_acd.py` | tests |
| `lib/task_pair_acd.sh` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_task_pair_acd_parser.yaml`*
*Last verified: 2026-05-06*
