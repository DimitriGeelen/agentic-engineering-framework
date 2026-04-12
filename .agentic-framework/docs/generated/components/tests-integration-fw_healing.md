# fw_healing

> Integration tests for fw healing CLI — 6 tests covering help, patterns, diagnose, and suggest.

**Type:** test | **Subsystem:** framework-core | **Location:** `tests/integration/fw_healing.bats`

**Tags:** `bats`, `integration-test`, `healing`, `cli`

## What It Does

Integration tests for fw healing subcommand
Tests the CLI interface for the healing loop:
fw healing diagnose T-XXX — analyze task issues
fw healing patterns       — show known failure patterns
fw healing suggest        — suggestions for tasks with issues

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `bin/fw` | calls |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_healing.yaml`*
*Last verified: 2026-03-30*
