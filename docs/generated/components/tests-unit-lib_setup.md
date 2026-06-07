# lib_setup

> Unit tests for setup (2 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/lib_setup.bats`

**Tags:** `setup`, `bats`, `unit-test`

## What It Does

Unit tests for lib/setup.sh
Tests do_setup argument parsing and help

## Dependencies (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [setup](/docs/generated/lib-setup) | calls | fw setup - Guided onboarding wizard for new projects |
| [colors](/docs/generated/lib-colors) | calls | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [errors](/docs/generated/lib-errors) | calls | Consistent error/warning/info output functions with TTY-aware coloring. Provides die(), error(), warn(), info(), success(), block() with standardized exit codes (0=ok, 1=error, 2=blocking). Auto-sourced by lib/paths.sh. |
| [setup](/docs/generated/lib-setup) | tests | fw setup - Guided onboarding wizard for new projects |
| [colors](/docs/generated/lib-colors) | tests | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [errors](/docs/generated/lib-errors) | tests | Consistent error/warning/info output functions with TTY-aware coloring. Provides die(), error(), warn(), info(), success(), block() with standardized exit codes (0=ok, 1=error, 2=blocking). Auto-sourced by lib/paths.sh. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-lib_setup.yaml`*
*Last verified: 2026-04-05*
