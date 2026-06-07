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

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [context-dispatcher](/docs/generated/context-dispatcher) | calls | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [compat](/docs/generated/lib-compat) | calls | Compatibility shims: bash 3.2 (macOS) POSIX-safe replacements for declare -A and other bashisms. |
| [status](/docs/generated/agents-context-lib-status) | calls | Context Agent - status command |
| [status](/docs/generated/agents-context-lib-status) | tests | Context Agent - status command |
| [compat](/docs/generated/lib-compat) | tests | Compatibility shims: bash 3.2 (macOS) POSIX-safe replacements for declare -A and other bashisms. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-context_status.yaml`*
*Last verified: 2026-04-05*
