# test_task_pair_acd_gate

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_task_pair_acd_gate.bats`

## What It Does

T-1762: task-pair §ACD gate (P-012) — gate behaviour (T-1713 Spike 3)
Tests for check_task_pair_acd in agents/task-create/update-task.sh
Pins gate behaviour:
- Build task with all promised deliverables shipped → passes
- Build task with missing deliverables → exit 1 with actionable message
- --scope-reduction-acknowledged "..." → bypasses with logged Tier-2 entry
- Build task whose inception has no Decomposition heading → no-op (single-deliverable)
- Non-build tasks (inception/spec/design) → no-op
- Build task with no related_tasks → no-op
- Existing P-010/P-011 still run before P-012 (regression)

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [task_pair_acd](/docs/generated/lib-task_pair_acd) | calls | TODO: describe what this component does |
| [update-task](/docs/generated/agents-task-create-update-task) | calls | Task Update Agent - Status transitions with auto-triggers |
| [update-task](/docs/generated/agents-task-create-update-task) | tests | Task Update Agent - Status transitions with auto-triggers |
| [task_pair_acd](/docs/generated/lib-task_pair_acd) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_task_pair_acd_gate.yaml`*
*Last verified: 2026-05-06*
