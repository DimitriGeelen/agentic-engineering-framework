# context_status

> Unit tests for context status (7 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/context_status.bats`

**Tags:** `context`, `status`, `bats`, `unit-test`

## What It Does

Unit tests for agents/context/lib/status.sh
Tests the do_status() function:
- Displays working memory, project memory, episodic memory sections
- Handles missing session.yaml gracefully
- Reports counts for patterns, decisions, learnings

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `agents/context/context.sh` | calls |

## Related

### Tasks
- T-758: Add unit tests for context pattern and status libs (16+ tests)

---
*Auto-generated from Component Fabric. Card: `tests-unit-context_status.yaml`*
*Last verified: 2026-04-05*
