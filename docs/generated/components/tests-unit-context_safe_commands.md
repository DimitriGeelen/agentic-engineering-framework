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

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [context-dispatcher](/docs/generated/context-dispatcher) | calls | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [safe-commands](/docs/generated/agents-context-lib-safe-commands) | calls | Allowlist of safe bash commands for task gate bypass — git status, ls, cat, grep etc. that dont need an active task. |
| [safe-commands](/docs/generated/agents-context-lib-safe-commands) | tests | Allowlist of safe bash commands for task gate bypass — git status, ls, cat, grep etc. that dont need an active task. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-context_safe_commands.yaml`*
*Last verified: 2026-04-05*
