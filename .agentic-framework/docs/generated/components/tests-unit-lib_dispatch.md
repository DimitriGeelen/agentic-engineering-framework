# lib_dispatch

> Unit tests for dispatch (9 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/lib_dispatch.bats`

**Tags:** `dispatch`, `bats`, `unit-test`

## What It Does

Unit tests for lib/dispatch.sh
Tests do_dispatch routing, help, send validation

## Dependencies (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [dispatch](/docs/generated/lib-dispatch) | calls | fw dispatch subcommand: cross-machine SSH-based result dispatch. Serializes bus envelopes and pipes via SSH to remote fw bus receive. |
| [colors](/docs/generated/lib-colors) | calls | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [errors](/docs/generated/lib-errors) | calls | Consistent error/warning/info output functions with TTY-aware coloring. Provides die(), error(), warn(), info(), success(), block() with standardized exit codes (0=ok, 1=error, 2=blocking). Auto-sourced by lib/paths.sh. |
| [dispatch](/docs/generated/lib-dispatch) | tests | fw dispatch subcommand: cross-machine SSH-based result dispatch. Serializes bus envelopes and pipes via SSH to remote fw bus receive. |
| [colors](/docs/generated/lib-colors) | tests | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [errors](/docs/generated/lib-errors) | tests | Consistent error/warning/info output functions with TTY-aware coloring. Provides die(), error(), warn(), info(), success(), block() with standardized exit codes (0=ok, 1=error, 2=blocking). Auto-sourced by lib/paths.sh. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-lib_dispatch.yaml`*
*Last verified: 2026-04-05*
