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

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2988_grouped_command_classification.yaml`*
*Last verified: 2026-08-14*
