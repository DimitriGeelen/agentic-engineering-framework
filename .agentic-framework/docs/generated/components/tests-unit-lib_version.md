# lib_version

> Unit tests for version (16 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/lib_version.bats`

**Tags:** `version`, `bats`, `unit-test`

## What It Does

Unit tests for lib/version.sh
Tests _read_fw_version(), do_version_bump (dry-run), do_version_check

## Dependencies (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [version](/docs/generated/lib-version) | calls | fw version subcommand: show framework version, git tag, commit count, paths. Supports --check for update detection. |
| [colors](/docs/generated/lib-colors) | calls | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [compat](/docs/generated/lib-compat) | calls | Compatibility shims: bash 3.2 (macOS) POSIX-safe replacements for declare -A and other bashisms. |
| [errors](/docs/generated/lib-errors) | calls | Consistent error/warning/info output functions with TTY-aware coloring. Provides die(), error(), warn(), info(), success(), block() with standardized exit codes (0=ok, 1=error, 2=blocking). Auto-sourced by lib/paths.sh. |
| [version](/docs/generated/lib-version) | tests | fw version subcommand: show framework version, git tag, commit count, paths. Supports --check for update detection. |
| [colors](/docs/generated/lib-colors) | tests | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [compat](/docs/generated/lib-compat) | tests | Compatibility shims: bash 3.2 (macOS) POSIX-safe replacements for declare -A and other bashisms. |
| [errors](/docs/generated/lib-errors) | tests | Consistent error/warning/info output functions with TTY-aware coloring. Provides die(), error(), warn(), info(), success(), block() with standardized exit codes (0=ok, 1=error, 2=blocking). Auto-sourced by lib/paths.sh. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-lib_version.yaml`*
*Last verified: 2026-04-05*
