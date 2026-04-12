# context_safe_commands

> Unit tests for context safe_commands (35 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/context_safe_commands.bats`

**Tags:** `context`, `safe_commands`, `bats`, `unit-test`

## What It Does

Unit tests for agents/context/lib/safe-commands.sh
Tests is_bash_safe_command() and has_bash_write_pattern():
- Git read-only commands allowed
- File reading commands allowed
- FW diagnostic commands allowed
- Write operations blocked
- Write pattern detection

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `agents/context/context.sh` | calls |

## Related

### Tasks
- T-762: Fix remaining shellcheck warnings + unit tests for episodic, init, safe-commands libs

---
*Auto-generated from Component Fabric. Card: `tests-unit-context_safe_commands.yaml`*
*Last verified: 2026-04-05*
