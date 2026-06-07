# lib_bus

> Unit tests for bus (24 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/lib_bus.bats`

**Tags:** `bus`, `bats`, `unit-test`

## What It Does

Unit tests for lib/bus.sh
Tests do_bus_post, do_bus_read, do_bus_manifest, do_bus_clear

## Dependencies (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [bus](/docs/generated/lib-bus) | calls | fw bus - Task-scoped result ledger for sub-agent communication |
| [colors](/docs/generated/lib-colors) | calls | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [errors](/docs/generated/lib-errors) | calls | Consistent error/warning/info output functions with TTY-aware coloring. Provides die(), error(), warn(), info(), success(), block() with standardized exit codes (0=ok, 1=error, 2=blocking). Auto-sourced by lib/paths.sh. |
| [bus](/docs/generated/lib-bus) | tests | fw bus - Task-scoped result ledger for sub-agent communication |
| [colors](/docs/generated/lib-colors) | tests | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [errors](/docs/generated/lib-errors) | tests | Consistent error/warning/info output functions with TTY-aware coloring. Provides die(), error(), warn(), info(), success(), block() with standardized exit codes (0=ok, 1=error, 2=blocking). Auto-sourced by lib/paths.sh. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-lib_bus.yaml`*
*Last verified: 2026-04-05*
