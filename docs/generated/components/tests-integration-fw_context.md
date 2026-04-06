# fw_context

> Integration tests for fw context CLI — 6 tests covering status, init, focus, and help.

**Type:** test | **Subsystem:** framework-core | **Location:** `tests/integration/fw_context.bats`

**Tags:** `bats`, `integration-test`, `context`, `cli`

## What It Does

Integration tests for fw context subcommand
Tests the CLI interface for context management:
fw context status — show context state
fw context init   — initialize session
fw context focus  — set/show current focus

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `bin/fw` | calls |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_context.yaml`*
*Last verified: 2026-03-29*
