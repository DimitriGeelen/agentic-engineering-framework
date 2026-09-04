# t3235_archived_horizon_invariant

> Pins that a task file under .tasks/completed/ carries horizon: null whichever branch archived it. Two branches move a task there and their entry conditions are exact complements, so the null-ing written at the first site (T-2163, widened T-2300 after eight CTL-030 instances) could never reach the partial-complete recheck branch. The sharp end is fw task archive-eligible, which re-invokes --status work-completed and therefore drives exclusively through the branch that was unfixed. Every leg asserts WHICH branch ran before asserting the outcome, because the obvious fixture leaves status started-work and never enters the recheck branch at all — a rig that checks only the outcome goes green against the wrong path. A control pins the deliberate case the fix must NOT break: a partial-complete that stays in active/ keeps its stored horizon, which is why the post-condition keys on location, not status. The mutation control removes the post-condition from a live-derived copy and needs a symlink farm, since update-task.sh derives FRAMEWORK_ROOT from its own location and a dead subject reads exactly like a regressed one. Reported by peer 832-Workflow-designer (their T-654 BUG 1); confirmed in-tree first.


**Type:** script | **Subsystem:** testing | **Location:** `tests/unit/t3235_archived_horizon_invariant.bats`

**Tags:** `regression`, `mutation-control`, `invariant`, `task-lifecycle`, `horizon`, `peer-report`, `T-3235`

## What It Does

T-3235 — a task file in .tasks/completed/ carries `horizon: null`, whichever
branch archived it.
Two branches in update-task.sh move a task into completed/, and their entry
conditions are EXACT COMPLEMENTS:
ordinary completion   OLD_STATUS != work-completed
partial-complete      OLD_STATUS == NEW_STATUS == work-completed,
recheck             file still in active/
T-2163 wrote the horizon null-ing inside the first, and T-2300 widened it
there after eight CTL-030 instances. No widening of a site can reach a branch
whose entry condition is that site's complement, so the recheck branch

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [update-task](/docs/generated/agents-task-create-update-task) | calls | Task Update Agent - Status transitions with auto-triggers |
| [update-task](/docs/generated/agents-task-create-update-task) | tests | Task Update Agent - Status transitions with auto-triggers |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3235_archived_horizon_invariant.yaml`*
*Last verified: 2026-08-31*
