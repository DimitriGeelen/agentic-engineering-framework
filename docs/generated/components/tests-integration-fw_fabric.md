# fw_fabric

> Integration tests for fw fabric CLI — 10 tests covering help, overview, stats, deps, search, and get.

**Type:** test | **Subsystem:** framework-core | **Location:** `tests/integration/fw_fabric.bats`

**Tags:** `bats`, `integration-test`, `fabric`, `cli`

## What It Does

Integration tests for fw fabric subcommand
Tests the CLI interface for fabric topology commands:
fw fabric help      — show usage
fw fabric overview  — compact subsystem summary
fw fabric stats     — component/edge counts
fw fabric deps      — dependencies for a file
fw fabric search    — search by keyword
fw fabric get       — show full component card

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `bin/fw` | calls |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_fabric.yaml`*
*Last verified: 2026-03-29*
