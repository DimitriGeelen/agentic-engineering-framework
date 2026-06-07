# lib_harvest

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/lib_harvest.bats`

## What It Does

Unit tests for lib/harvest.sh
Tests do_harvest argument parsing, help, guards, and sub-functions

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [harvest](/docs/generated/lib-harvest) | calls | fw harvest - Collect learnings from projects back into the framework |
| [colors](/docs/generated/lib-colors) | calls | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [harvest](/docs/generated/lib-harvest) | tests | fw harvest - Collect learnings from projects back into the framework |
| [colors](/docs/generated/lib-colors) | tests | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-lib_harvest.yaml`*
*Last verified: 2026-03-30*
