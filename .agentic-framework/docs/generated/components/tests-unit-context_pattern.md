# context_pattern

> Unit tests for context pattern (11 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/context_pattern.bats`

**Tags:** `context`, `pattern`, `bats`, `unit-test`

## What It Does

Unit tests for agents/context/lib/pattern.sh
Tests the do_add_pattern() function:
- Pattern type validation (failure/success/workflow)
- ID generation with type-specific prefixes (FP/SP/WP)
- File creation and section appending
- Mitigation (failure patterns only)

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `agents/context/context.sh` | calls |

---
*Auto-generated from Component Fabric. Card: `tests-unit-context_pattern.yaml`*
*Last verified: 2026-04-05*
