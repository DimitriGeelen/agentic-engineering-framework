# fw_inception

> Integration tests for fw inception CLI — 5 tests covering help, status, start, workflow type, and status listing.

**Type:** test | **Subsystem:** framework-core | **Location:** `tests/integration/fw_inception.bats`

**Tags:** `bats`, `integration-test`, `inception`, `cli`

## What It Does

Integration tests for fw inception subcommand
Tests the CLI interface for inception workflow:
fw inception           — show help
fw inception status    — list inception tasks
fw inception start     — create inception task

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `bin/fw` | calls |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_inception.yaml`*
*Last verified: 2026-03-30*
