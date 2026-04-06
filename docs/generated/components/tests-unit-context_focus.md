# context_focus

> Unit tests for context focus (15 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/context_focus.bats`

**Tags:** `context`, `focus`, `bats`, `unit-test`

## What It Does

Unit tests for agents/context/lib/focus.sh
Tests the do_focus() function:
- No args: show current focus from focus.yaml
- With arg: set focus to a task (validates existence, updates focus.yaml + session.yaml)

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `agents/context/context.sh` | calls |

---
*Auto-generated from Component Fabric. Card: `tests-unit-context_focus.yaml`*
*Last verified: 2026-04-05*
