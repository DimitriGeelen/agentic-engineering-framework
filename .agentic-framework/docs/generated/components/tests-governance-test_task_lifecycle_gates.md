# test_task_lifecycle_gates

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/governance/test_task_lifecycle_gates.bats`

## What It Does

T-1608 (T-1601 GO follow-up, Phase 3): red-team harness for task-lifecycle gates.
Phase 1 (T-1606) covered 7 PreToolUse hooks. Phase 2 (T-1607) covered 3 git hooks.
Phase 3 closes the loop on the 4 task-lifecycle gates:
- P-010: unchecked AC gate    (agents/task-create/update-task.sh:check_acceptance_criteria)
- P-011: verification gate    (agents/task-create/update-task.sh:run_verification_commands)
- RCA gate (T-1550)          (agents/task-create/update-task.sh:check_rca_for_bugfix)
- inception-decide CLAUDECODE (lib/inception.sh:do_inception_decide)
Block-only coverage. Allow paths trigger irreversible side effects (move task to
completed/, episodic generation, fabric updates) that we don't want to mutate
in the framework repo. The block paths are what governance regression detection

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `bin/fw` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-governance-test_task_lifecycle_gates.yaml`*
*Last verified: 2026-04-29*
