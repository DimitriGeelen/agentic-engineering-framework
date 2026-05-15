# context_decision

> Unit tests for context decision (11 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/context_decision.bats`

**Tags:** `context`, `decision`, `bats`, `unit-test`

## What It Does

Unit tests for agents/context/lib/decision.sh
Tests the do_add_decision() function:
- Argument parsing (decision text, --task, --rationale, --rejected)
- Error handling (missing text)
- ID generation (D-XXX or PD-XXX)
- File creation and appending
- Output formatting

## Dependencies (5)

| Target | Relationship |
|--------|-------------|
| `agents/context/context.sh` | calls |
| `lib/compat.sh` | calls |
| `agents/context/lib/decision.sh` | calls |
| `agents/context/lib/decision.sh` | tests |
| `lib/compat.sh` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-context_decision.yaml`*
*Last verified: 2026-04-05*
