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

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [context-dispatcher](/docs/generated/context-dispatcher) | calls | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [compat](/docs/generated/lib-compat) | calls | Compatibility shims: bash 3.2 (macOS) POSIX-safe replacements for declare -A and other bashisms. |
| [add-learning](/docs/generated/add-learning) | calls | Add a learning entry to project memory (learnings.yaml). Assigns next L-XXX ID, formats YAML, inserts before candidates section. |
| [add-learning](/docs/generated/add-learning) | tests | Add a learning entry to project memory (learnings.yaml). Assigns next L-XXX ID, formats YAML, inserts before candidates section. |
| [compat](/docs/generated/lib-compat) | tests | Compatibility shims: bash 3.2 (macOS) POSIX-safe replacements for declare -A and other bashisms. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-context_learning.yaml`*
*Last verified: 2026-04-05*
