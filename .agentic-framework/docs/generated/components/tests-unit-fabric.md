# fabric

> Unit tests for agents/fabric/fabric.sh (10 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/fabric.bats`

**Tags:** `fabric`, `bats`, `unit-test`

## What It Does

Unit tests for agents/fabric/fabric.sh
Origin: T-931

### Framework Reference

The Component Fabric (`.fabric/`) is a structural topology map of every significant file in the framework. It enables impact analysis, dependency tracking, and onboarding.

### When to Use

- **Before modifying a file:** `fw fabric deps <path>` — see what depends on it and what it depends on
- **Before committing:** `fw fabric blast-radius` — see downstream impact of your changes
- **After creating new files:** `fw fabric register <path>` — create a component card
- **Periodic health check:** `fw fabric drift` — detect unregistered, orphaned, or stale components

### Key Commands

*(truncated — see CLAUDE.md for full section)*

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `agents/fabric/fabric.sh` | calls |

## Related

### Tasks
- T-931: Add unit tests for agents/fabric/fabric.sh

---
*Auto-generated from Component Fabric. Card: `tests-unit-fabric.yaml`*
*Last verified: 2026-04-05*
