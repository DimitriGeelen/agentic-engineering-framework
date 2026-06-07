# lib_update

> Unit tests for update (3 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/lib_update.bats`

**Tags:** `update`, `bats`, `unit-test`

## What It Does

Unit tests for lib/update.sh
Tests do_update argument parsing and help

## Dependencies (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [update](/docs/generated/lib-update) | calls | fw update subcommand: CLI wrapper for framework self-update. Pulls latest, runs upgrade, reports changes. |
| [colors](/docs/generated/lib-colors) | calls | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [errors](/docs/generated/lib-errors) | calls | Consistent error/warning/info output functions with TTY-aware coloring. Provides die(), error(), warn(), info(), success(), block() with standardized exit codes (0=ok, 1=error, 2=blocking). Auto-sourced by lib/paths.sh. |
| [compat](/docs/generated/lib-compat) | calls | Compatibility shims: bash 3.2 (macOS) POSIX-safe replacements for declare -A and other bashisms. |
| [update](/docs/generated/lib-update) | tests | fw update subcommand: CLI wrapper for framework self-update. Pulls latest, runs upgrade, reports changes. |
| [colors](/docs/generated/lib-colors) | tests | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [errors](/docs/generated/lib-errors) | tests | Consistent error/warning/info output functions with TTY-aware coloring. Provides die(), error(), warn(), info(), success(), block() with standardized exit codes (0=ok, 1=error, 2=blocking). Auto-sourced by lib/paths.sh. |
| [compat](/docs/generated/lib-compat) | tests | Compatibility shims: bash 3.2 (macOS) POSIX-safe replacements for declare -A and other bashisms. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-lib_update.yaml`*
*Last verified: 2026-04-05*
