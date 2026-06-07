# lib_inception

> Unit tests for inception (12 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/lib_inception.bats`

**Tags:** `inception`, `bats`, `unit-test`

## What It Does

Unit tests for lib/inception.sh
Tests do_inception routing, show_inception_help, argument validation

## Dependencies (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [inception](/docs/generated/lib-inception) | calls | fw inception - Inception phase workflow |
| [colors](/docs/generated/lib-colors) | calls | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [errors](/docs/generated/lib-errors) | calls | Consistent error/warning/info output functions with TTY-aware coloring. Provides die(), error(), warn(), info(), success(), block() with standardized exit codes (0=ok, 1=error, 2=blocking). Auto-sourced by lib/paths.sh. |
| [tasks](/docs/generated/lib-tasks) | calls | fw task subcommand dispatcher: routes task create/update/list/verify/review to agents/task-create/ scripts. |
| [inception](/docs/generated/lib-inception) | tests | fw inception - Inception phase workflow |
| [colors](/docs/generated/lib-colors) | tests | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [errors](/docs/generated/lib-errors) | tests | Consistent error/warning/info output functions with TTY-aware coloring. Provides die(), error(), warn(), info(), success(), block() with standardized exit codes (0=ok, 1=error, 2=blocking). Auto-sourced by lib/paths.sh. |
| [tasks](/docs/generated/lib-tasks) | tests | fw task subcommand dispatcher: routes task create/update/list/verify/review to agents/task-create/ scripts. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-lib_inception.yaml`*
*Last verified: 2026-04-05*
