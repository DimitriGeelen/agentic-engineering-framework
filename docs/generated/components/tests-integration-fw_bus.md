# fw_bus

> Integration tests for fw bus CLI.

**Type:** test | **Subsystem:** framework-core | **Location:** `tests/integration/fw_bus.bats`

**Tags:** `bats`, `integration-test`, `bus`, `cli`

## What It Does

Integration tests for fw bus subcommand
Tests the CLI interface for the task-scoped result ledger:
fw bus              — show help
fw bus post         — post a result
fw bus manifest     — show results summary
fw bus read         — read results
fw bus clear        — clear results

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `bin/fw` | calls |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_bus.yaml`*
*Last verified: 2026-03-30*
