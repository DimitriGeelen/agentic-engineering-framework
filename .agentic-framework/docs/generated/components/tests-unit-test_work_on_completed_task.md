# test_work_on_completed_task

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_work_on_completed_task.bats`

## What It Does

T-2036 — Pin `fw work-on T-XXX` behaviour against the P-002 "completed
before commit" deadlock.
Origin: T-2035 (session S-2026-0522-1941). If an agent runs
`fw task update T-XXX --status work-completed` before committing the
code, focus is nulled, the file moves to .tasks/completed/, and the
check-active-task PreToolUse hook blocks every subsequent Bash mutation
(git add/commit). The previous "recovery" `fw work-on T-XXX` silently
false-succeeded — printed "Ready to work on T-XXX" while the task stayed
in completed/ (work-completed is terminal in lib/enums.sh; update-task's
transition failure was swallowed by `2>/dev/null || true`).

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [enums](/docs/generated/lib-enums) | tests | Single source of truth for framework enumerations — valid statuses, workflow types, horizons, and status transitions. Provides is_valid_status(), is_valid_type(), is_valid_horizon(), is_valid_transition() functions. Replaces hardcoded lists previously duplicated across 6+ files. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_work_on_completed_task.yaml`*
*Last verified: 2026-05-27*
