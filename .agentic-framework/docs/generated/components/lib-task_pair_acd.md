# task_pair_acd

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/task_pair_acd.sh`

## What It Does

lib/task_pair_acd.sh
Task-pair §ACD gate (P-012). G-066 prong 2 — detect substrate-vs-
deliverable conflation at work-completed time. Mirror of T-1668/T-1671's
arc-level gate at the per-task level.
Built from T-1713 GO decision (2026-05-04). T-1713 itself shipped the
pattern G-066 documents: inception with GO scope, no build task ever
filed, gate never wired. T-1762 closes that loop.
Public functions:
extract_deliverables <inception_task_file>
Print one promised deliverable per line from the inception's

## Used By (7)

| Component | Relationship |
|-----------|-------------|
| `agents/task-create/update-task.sh` | called_by |
| `tests/playwright/test_review_code_inline.py` | called_by |
| `tests/unit/test_file_route_extensions.py` | called_by |
| `tests/unit/test_task_pair_acd_gate.bats` | called_by |
| `tests/unit/test_task_pair_acd_gate.bats` | tests_by |
| `tests/unit/test_task_pair_acd_parser.bats` | called_by |
| `tests/unit/test_task_pair_acd_parser.bats` | tests_by |

---
*Auto-generated from Component Fabric. Card: `lib-task_pair_acd.yaml`*
*Last verified: 2026-05-06*
