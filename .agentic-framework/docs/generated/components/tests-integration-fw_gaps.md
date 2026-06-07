# fw_gaps

> Integration tests for fw gaps CLI.

**Type:** test | **Subsystem:** framework-core | **Location:** `tests/integration/fw_gaps.bats`

**Tags:** `bats`, `integration-test`, `gaps`, `cli`

## What It Does

Integration tests for fw gaps subcommand
Tests the CLI interface for the gaps register:
fw gaps — display gaps from concerns.yaml

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_gaps.yaml`*
*Last verified: 2026-03-30*
