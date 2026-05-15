# task_pair_acd-py

> Task-pair §ACD gate (P-012, T-1762) — Python core. Parses inception Recommendation->Decomposition headings, verifies promised follow-up build tasks shipped via related_tasks chain. Mirror of T-1668/T-1671 arc-level §ACD gate at task-pair level (G-066 prong 2 implementation per T-1713 GO).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/task_pair_acd.py`

**Tags:** `lib`, `governance-gate`, `ACD`, `G-066`

## What It Does

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `.tasks/completed` | reads |
| `.tasks/active` | reads |

## Used By (5)

| Component | Relationship |
|-----------|-------------|
| `lib/task_pair_acd.sh` | called_by |
| `agents/task-create/update-task.sh` | called_by |
| `tests/unit/test_file_route_extensions.py` | called_by |
| `tests/unit/test_task_pair_acd_parser.bats` | called_by |
| `tests/unit/test_task_pair_acd_parser.bats` | tests_by |

---
*Auto-generated from Component Fabric. Card: `lib-task_pair_acd-py.yaml`*
*Last verified: 2026-05-06*
