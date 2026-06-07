# context_episodic

> Unit tests for context episodic (11 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/context_episodic.bats`

**Tags:** `context`, `episodic`, `bats`, `unit-test`

## What It Does

Unit tests for agents/context/lib/episodic.sh
Tests git-mining helpers and do_generate_episodic():
- Error handling for missing task ID
- Error handling for missing task file
- Episodic file creation
- Git timeline mining
- AC parsing and outcome extraction

## Dependencies (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [context-dispatcher](/docs/generated/context-dispatcher) | calls | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [compat](/docs/generated/lib-compat) | calls | Compatibility shims: bash 3.2 (macOS) POSIX-safe replacements for declare -A and other bashisms. |
| [tasks](/docs/generated/lib-tasks) | calls | fw task subcommand dispatcher: routes task create/update/list/verify/review to agents/task-create/ scripts. |
| [episodic](/docs/generated/agents-context-lib-episodic) | calls | Context Agent - generate-episodic command |
| [episodic](/docs/generated/agents-context-lib-episodic) | tests | Context Agent - generate-episodic command |
| [compat](/docs/generated/lib-compat) | tests | Compatibility shims: bash 3.2 (macOS) POSIX-safe replacements for declare -A and other bashisms. |
| [tasks](/docs/generated/lib-tasks) | tests | fw task subcommand dispatcher: routes task create/update/list/verify/review to agents/task-create/ scripts. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-context_episodic.yaml`*
*Last verified: 2026-04-05*
