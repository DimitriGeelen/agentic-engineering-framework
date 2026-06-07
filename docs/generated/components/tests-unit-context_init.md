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

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [context-dispatcher](/docs/generated/context-dispatcher) | calls | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [init](/docs/generated/agents-context-lib-init) | calls | Context Agent - init command |
| [init](/docs/generated/agents-context-lib-init) | tests | Context Agent - init command |

---
*Auto-generated from Component Fabric. Card: `tests-unit-context_init.yaml`*
*Last verified: 2026-04-05*
