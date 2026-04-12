# context_learning

> Unit tests for context learning (10 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/context_learning.bats`

**Tags:** `context`, `learning`, `bats`, `unit-test`

## What It Does

Unit tests for agents/context/lib/learning.sh
Tests the do_add_learning() function:
- Argument parsing (learning text, --task, --source)
- Error handling (missing text)
- ID generation (L-XXX or PL-XXX)
- File creation and appending
- Output formatting

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `agents/context/context.sh` | calls |

---
*Auto-generated from Component Fabric. Card: `tests-unit-context_learning.yaml`*
*Last verified: 2026-04-05*
