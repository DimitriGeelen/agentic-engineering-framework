# context_focus

> Unit tests for context focus (15 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/context_focus.bats`

**Tags:** `context`, `focus`, `bats`, `unit-test`

## What It Does

Unit tests for agents/context/lib/focus.sh
Tests the do_focus() function:
- No args: show current focus from focus.yaml
- With arg: set focus to a task (validates existence, updates focus.yaml + session.yaml)

## Dependencies (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [context-dispatcher](/docs/generated/context-dispatcher) | calls | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [compat](/docs/generated/lib-compat) | calls | Compatibility shims: bash 3.2 (macOS) POSIX-safe replacements for declare -A and other bashisms. |
| [tasks](/docs/generated/lib-tasks) | calls | fw task subcommand dispatcher: routes task create/update/list/verify/review to agents/task-create/ scripts. |
| [focus](/docs/generated/agents-context-lib-focus) | calls | Context Agent - focus command |
| [focus](/docs/generated/agents-context-lib-focus) | tests | Context Agent - focus command |
| [compat](/docs/generated/lib-compat) | tests | Compatibility shims: bash 3.2 (macOS) POSIX-safe replacements for declare -A and other bashisms. |
| [tasks](/docs/generated/lib-tasks) | tests | fw task subcommand dispatcher: routes task create/update/list/verify/review to agents/task-create/ scripts. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-context_focus.yaml`*
*Last verified: 2026-04-05*
