# test_task_pair_acd_parser

> T-1762: task-pair §ACD gate (P-012) — parser spike (T-1713 Spike 1)

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_task_pair_acd_parser.bats`

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

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [task_pair_acd](/docs/generated/lib-task_pair_acd) | calls | Task-pair §ACD gate (P-012). G-066 prong 2 — detect substrate-vs- deliverable conflation at work-completed time. Mirror of T-1668/T-1671's arc-level gate at the per-task level. |
| [task_pair_acd-py](/docs/generated/lib-task_pair_acd-py) | calls | Task-pair §ACD gate (P-012, T-1762) — Python core. Parses inception Recommendation->Decomposition headings, verifies promised follow-up build tasks shipped via related_tasks chain. Mirror of T-1668/T-1671 arc-level §ACD gate at task-pair level (G-066 prong 2 implementation per T-1713 GO). |
| [task_pair_acd-py](/docs/generated/lib-task_pair_acd-py) | tests | Task-pair §ACD gate (P-012, T-1762) — Python core. Parses inception Recommendation->Decomposition headings, verifies promised follow-up build tasks shipped via related_tasks chain. Mirror of T-1668/T-1671 arc-level §ACD gate at task-pair level (G-066 prong 2 implementation per T-1713 GO). |
| [task_pair_acd](/docs/generated/lib-task_pair_acd) | tests | Task-pair §ACD gate (P-012). G-066 prong 2 — detect substrate-vs- deliverable conflation at work-completed time. Mirror of T-1668/T-1671's arc-level gate at the per-task level. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_task_pair_acd_parser.yaml`*
*Last verified: 2026-05-06*
