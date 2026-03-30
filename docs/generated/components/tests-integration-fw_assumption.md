# fw_assumption

> Integration tests for fw assumption CLI.

**Type:** test | **Subsystem:** framework-core | **Location:** `tests/integration/fw_assumption.bats`

**Tags:** `bats`, `integration-test`, `assumption`, `cli`

## What It Does

Integration tests for fw assumption subcommand
Tests the CLI interface for assumption tracking:
fw assumption           — show help
fw assumption add       — register an assumption
fw assumption list      — list assumptions
fw assumption validate  — mark as validated

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `bin/fw` | calls |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_assumption.yaml`*
*Last verified: 2026-03-30*
