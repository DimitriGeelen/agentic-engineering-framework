# fw_handover

> Integration tests for fw handover CLI — 4 tests covering help, file creation, sections, and output.

**Type:** test | **Subsystem:** framework-core | **Location:** `tests/integration/fw_handover.bats`

**Tags:** `bats`, `integration-test`, `handover`, `cli`

## What It Does

Integration tests for fw handover subcommand
Tests the CLI interface for session handover:
fw handover            — generate handover document
fw handover --help     — show help
fw handover --no-commit — generate without committing

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `bin/fw` | calls |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_handover.yaml`*
*Last verified: 2026-03-30*
