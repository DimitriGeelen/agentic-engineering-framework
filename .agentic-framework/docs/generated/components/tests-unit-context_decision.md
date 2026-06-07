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

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [context-dispatcher](/docs/generated/context-dispatcher) | calls | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [compat](/docs/generated/lib-compat) | calls | Compatibility shims: bash 3.2 (macOS) POSIX-safe replacements for declare -A and other bashisms. |
| [decision](/docs/generated/agents-context-lib-decision) | calls | Context Agent - add-decision command |
| [decision](/docs/generated/agents-context-lib-decision) | tests | Context Agent - add-decision command |
| [compat](/docs/generated/lib-compat) | tests | Compatibility shims: bash 3.2 (macOS) POSIX-safe replacements for declare -A and other bashisms. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-context_decision.yaml`*
*Last verified: 2026-04-05*
