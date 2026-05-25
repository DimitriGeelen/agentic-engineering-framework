# safe_commands_env_prefix

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/safe_commands_env_prefix.bats`

## What It Does

T-1908: pin env-var prefix stripping in is_bash_safe_command.
L-399 / T-1890 contracted FW_SWITCH_FOCUS=1 as a universal bypass mechanism
(the env-var form works where --switch-focus flags can't, e.g. git commit).
But the safe-command extractor's awk '{print $1}' returned the env-prefix
as the base command — `FW_SWITCH_FOCUS=1 fw work-on T-X` was classified as
unsafe because `FW_SWITCH_FOCUS=1` didn't match any case in the allowlist.
Result: agent followed the documented bypass and got blocked anyway.

## Dependencies (3)

| Target | Relationship |
|--------|-------------|
| `agents/context/lib/safe-commands.sh` | calls |
| `agents/context/lib/safe-commands.sh` | tests |
| `bin/fw` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-safe_commands_env_prefix.yaml`*
*Last verified: 2026-05-18*
