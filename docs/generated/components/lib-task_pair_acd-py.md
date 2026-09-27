# task_pair_acd-py

> Task-pair §ACD gate (P-012, T-1762) — Python core. Parses inception Recommendation->Decomposition headings, verifies promised follow-up build tasks shipped via related_tasks chain. Mirror of T-1668/T-1671 arc-level §ACD gate at task-pair level (G-066 prong 2 implementation per T-1713 GO).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/task_pair_acd.py`

**Tags:** `lib`, `governance-gate`, `ACD`, `G-066`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| `.tasks/completed` | reads | — |
| `.tasks/active` | reads | — |

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [task_pair_acd](/docs/generated/lib-task_pair_acd) | called_by | Task-pair §ACD gate (P-012). G-066 prong 2 — detect substrate-vs- deliverable conflation at work-completed time. Mirror of T-1668/T-1671's arc-level gate at the per-task level. |
| [update-task](/docs/generated/agents-task-create-update-task) | called_by | Task Update Agent - Status transitions with auto-triggers |
| [test_file_route_extensions](/docs/generated/tests-unit-test_file_route_extensions) | called_by | T-1764: Regression tests for the /file/<path> route. |
| [test_task_pair_acd_parser](/docs/generated/tests-unit-test_task_pair_acd_parser) | called_by | T-1762: task-pair §ACD gate (P-012) — parser spike (T-1713 Spike 1) |
| [test_task_pair_acd_parser](/docs/generated/tests-unit-test_task_pair_acd_parser) | tests_by | T-1762: task-pair §ACD gate (P-012) — parser spike (T-1713 Spike 1) |

---
*Auto-generated from Component Fabric. Card: `lib-task_pair_acd-py.yaml`*
*Last verified: 2026-05-06*
