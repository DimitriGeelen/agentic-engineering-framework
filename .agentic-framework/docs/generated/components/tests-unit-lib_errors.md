# lib_errors

> Unit tests for errors (11 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/lib_errors.bats`

**Tags:** `errors`, `bats`, `unit-test`

## What It Does

Unit tests for lib/errors.sh
Tests die, error, warn, info, success, block output functions

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [errors](/docs/generated/lib-errors) | calls | Consistent error/warning/info output functions with TTY-aware coloring. Provides die(), error(), warn(), info(), success(), block() with standardized exit codes (0=ok, 1=error, 2=blocking). Auto-sourced by lib/paths.sh. |
| [errors](/docs/generated/lib-errors) | tests | Consistent error/warning/info output functions with TTY-aware coloring. Provides die(), error(), warn(), info(), success(), block() with standardized exit codes (0=ok, 1=error, 2=blocking). Auto-sourced by lib/paths.sh. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-lib_errors.yaml`*
*Last verified: 2026-04-05*
