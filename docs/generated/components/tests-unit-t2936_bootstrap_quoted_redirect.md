# t2936_bootstrap_quoted_redirect

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2936_bootstrap_quoted_redirect.bats`

## What It Does

T-2936 — the task gate refused both commands its own block message prescribes.
With focus null:
bin/fw task create --name "correct OBS-231 invalid-owner count 11->10 (...)" --start
→ BLOCKED: No active task. To unblock: 1. bin/fw task create ...
`check-active-task.sh` tested write-patterns before the task-bootstrap exemption
(T-2052, ~:198), and its own comment recorded the ordering as safe — "Reached only
when no write pattern is present". That holds only if a write pattern means a write.
`11->10` matches `[^2>&]>[^>&]` from INSIDE A QUOTED --name, so creating a task read
as a file write and was blocked for having no active task.
The deadlock is the point: creating the task is what would satisfy the gate, and the

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-active-task](/docs/generated/agents-context-check-active-task) | calls | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [safe-commands](/docs/generated/agents-context-lib-safe-commands) | calls | Allowlist of safe bash commands for task gate bypass — git status, ls, cat, grep etc. that dont need an active task. |
| [check-active-task](/docs/generated/agents-context-check-active-task) | tests | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [safe-commands](/docs/generated/agents-context-lib-safe-commands) | tests | Allowlist of safe bash commands for task gate bypass — git status, ls, cat, grep etc. that dont need an active task. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2936_bootstrap_quoted_redirect.yaml`*
*Last verified: 2026-08-12*
