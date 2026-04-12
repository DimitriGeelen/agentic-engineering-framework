# context_init

> Unit tests for context init (16 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/context_init.bats`

**Tags:** `context`, `init`, `bats`, `unit-test`

## What It Does

Unit tests for agents/context/lib/init.sh
Tests do_init():
- Creates session.yaml and focus.yaml
- Generates session ID format
- Resets tool counter and budget gate counter
- Detects first session vs existing project
- Reports predecessor from handover

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `agents/context/context.sh` | calls |

## Related

### Tasks
- T-762: Fix remaining shellcheck warnings + unit tests for episodic, init, safe-commands libs

---
*Auto-generated from Component Fabric. Card: `tests-unit-context_init.yaml`*
*Last verified: 2026-04-05*
