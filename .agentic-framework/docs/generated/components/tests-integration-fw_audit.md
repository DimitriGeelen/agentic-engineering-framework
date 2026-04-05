# fw_audit

> Integration tests for fw audit CLI — 3 tests covering help, section run, and YAML output.

**Type:** test | **Subsystem:** framework-core | **Location:** `tests/integration/fw_audit.bats`

**Tags:** `bats`, `integration-test`, `audit`, `cli`

## What It Does

Integration tests for fw audit subcommand
Tests the CLI interface for compliance audit:
fw audit                — run all audit sections
fw audit --section X    — run specific section
fw audit --help         — show help

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `bin/fw` | calls |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_audit.yaml`*
*Last verified: 2026-03-30*
