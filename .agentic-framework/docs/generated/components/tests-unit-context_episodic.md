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

| Target | Relationship |
|--------|-------------|
| `agents/context/context.sh` | calls |
| `lib/compat.sh` | calls |
| `lib/tasks.sh` | calls |
| `agents/context/lib/episodic.sh` | calls |
| `agents/context/lib/episodic.sh` | tests |
| `lib/compat.sh` | tests |
| `lib/tasks.sh` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-context_episodic.yaml`*
*Last verified: 2026-04-05*
