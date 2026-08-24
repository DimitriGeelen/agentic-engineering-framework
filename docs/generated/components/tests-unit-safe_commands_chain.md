# safe_commands_chain

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/safe_commands_chain.bats`

## What It Does

T-2834 / OBS-183 — a compound command is safe only if EVERY segment is safe.
Before this, is_bash_safe_command() derived the base with `awk '{print $1}'`
and its own comment asserted "for compound commands, the first word is still
the primary command". check-active-task.sh:95 treats a safe verdict as
terminal and exits 0, so `echo hi && <anything>` skipped the no-active-task
check, the task-is-active check, the G-020 readiness gate and the T-1730
focus-drift gate. Everything after the chain operator was unexamined.
Both directions are pinned here on purpose. The chained-unsafe direction is
the bug. The chained-SAFE direction is the regression risk: `cd X && fw Y`
and `ls && git status` are shapes agents run constantly, and a fix that

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [safe-commands](/docs/generated/agents-context-lib-safe-commands) | calls | Allowlist of safe bash commands for task gate bypass — git status, ls, cat, grep etc. that dont need an active task. |
| [safe-commands](/docs/generated/agents-context-lib-safe-commands) | tests | Allowlist of safe bash commands for task gate bypass — git status, ls, cat, grep etc. that dont need an active task. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-safe_commands_chain.yaml`*
*Last verified: 2026-08-06*
