# fabric

> Unit tests for agents/fabric/fabric.sh (10 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/fabric.bats`

**Tags:** `fabric`, `bats`, `unit-test`

## What It Does

Unit tests for agents/fabric/fabric.sh
Origin: T-931

### Framework Reference

The Component Fabric (`.fabric/`) is a structural topology map of every significant file — each component has a YAML card in `.fabric/components/` with id, name, type, subsystem, location, purpose, interfaces, depends_on, depended_by.

**When to use:** before modifying a file → `fw fabric deps <path>`; before committing → `fw fabric blast-radius [ref]`; after creating a new file → `fw fabric register <path>`; periodic health → `fw fabric drift` (detects unregistered/orphaned/stale). Also: `fw fabric overview` for the subsystem summary, `fw fabric impact <path>` for the full downstream chain, `

*(truncated — see CLAUDE.md for full section)*

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fabric](/docs/generated/agents-fabric-fabric) | calls | Fabric Agent - Component topology system for codebase self-awareness |
| [fabric](/docs/generated/agents-fabric-fabric) | tests | Fabric Agent - Component topology system for codebase self-awareness |
| [config](/docs/generated/lib-config) | tests | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |

## Related

### Tasks
- T-931: Add unit tests for agents/fabric/fabric.sh

---
*Auto-generated from Component Fabric. Card: `tests-unit-fabric.yaml`*
*Last verified: 2026-04-05*
