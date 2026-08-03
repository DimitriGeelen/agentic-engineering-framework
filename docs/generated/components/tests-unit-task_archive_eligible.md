# task_archive_eligible

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/task_archive_eligible.bats`

## What It Does

T-1903 / L-403: `fw task archive-eligible` sweep — detect tasks stuck in
.tasks/active/ with status: work-completed + all ACs ticked (the post-
re-class trap) and move them to .tasks/completed/.
Origin: T-1890 found this state after T-1894 re-classed its only Human AC
to [REVIEWER] under ### Agent. The first work-completed transition had set
PARTIAL_COMPLETE=true (Human AC unchecked at the time) → owner=human, file
stayed in active/. The recheck logic in update-task.sh (line ~941) only
fires when --status work-completed is re-invoked — which nothing does
automatically after a re-class. Sweep verb runs that re-invocation in bulk.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-task_archive_eligible.yaml`*
*Last verified: 2026-05-18*
