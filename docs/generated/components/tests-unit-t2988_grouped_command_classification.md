# t2988_grouped_command_classification

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2988_grouped_command_classification.bats`

## What It Does

T-2988: shell grouping punctuation defeated safe-command classification.
Reported from a consumer project inside a git worktree: an `fw note` call — a pure
observation capture, safe-listed, writing only to .context/ — was blocked with
"Project initialized but session not active". The bare form was allowed. The command
was wrapped in a subshell.
_fw_single_command_is_safe reads two tokens POSITIONALLY:
base=$(echo "$cmd" | awk '{print $1}' | sed 's|.*/||')     # the command
git_sub=$(echo "$cmd" | awk '{print $2}')                  # the sub-verb
so a grouping character touching either token corrupts it:
(fw doctor)      -> base `(fw`      no case arm matches

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-active-task](/docs/generated/agents-context-check-active-task) | calls | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [safe-commands](/docs/generated/agents-context-lib-safe-commands) | calls | Allowlist of safe bash commands for task gate bypass — git status, ls, cat, grep etc. that dont need an active task. |
| [check-active-task](/docs/generated/agents-context-check-active-task) | tests | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [safe-commands](/docs/generated/agents-context-lib-safe-commands) | tests | Allowlist of safe bash commands for task gate bypass — git status, ls, cat, grep etc. that dont need an active task. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2988_grouped_command_classification.yaml`*
*Last verified: 2026-08-14*
