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

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_context.yaml`*
*Last verified: 2026-03-29*
