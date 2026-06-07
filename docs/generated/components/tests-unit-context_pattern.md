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

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [context-dispatcher](/docs/generated/context-dispatcher) | calls | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [compat](/docs/generated/lib-compat) | calls | Compatibility shims: bash 3.2 (macOS) POSIX-safe replacements for declare -A and other bashisms. |
| [pattern](/docs/generated/agents-context-lib-pattern) | calls | Context Agent - add-pattern command |
| [pattern](/docs/generated/agents-context-lib-pattern) | tests | Context Agent - add-pattern command |
| [compat](/docs/generated/lib-compat) | tests | Compatibility shims: bash 3.2 (macOS) POSIX-safe replacements for declare -A and other bashisms. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-context_pattern.yaml`*
*Last verified: 2026-04-05*
