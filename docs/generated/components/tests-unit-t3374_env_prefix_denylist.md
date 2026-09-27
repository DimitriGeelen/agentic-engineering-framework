# t3374_env_prefix_denylist

> T-3374 (OBS-423) — the env-prefix stripper must refuse names that decide what the command it strips them from actually RESOLVES to.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3374_env_prefix_denylist.bats`

## What It Does

T-3374 (OBS-423) — the env-prefix stripper must refuse names that decide what
the command it strips them from actually RESOLVES to.
Before this fix, `is_bash_safe_command` returned SAFE for all four of:
PATH=/tmp cat x    LD_PRELOAD=/tmp/e.so cat x
BASH_ENV=/tmp/e.sh cat x    IFS=x cat y
because the T-1908 stripper removed ANY `NAME=VALUE` prefix and then judged the
base command that was left. The discarded prefix is the part that mattered.
CONTROL LEG. Every assertion below must FAIL against the pre-fix source, or it
is pinning nothing. Point the suite at any older copy of the library to prove
that — this is how the control was demonstrated for the task's AC:

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [safe-commands](/docs/generated/agents-context-lib-safe-commands) | tests | Allowlist of safe bash commands for task gate bypass — git status, ls, cat, grep etc. that dont need an active task. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3374_env_prefix_denylist.yaml`*
*Last verified: 2026-09-16*
