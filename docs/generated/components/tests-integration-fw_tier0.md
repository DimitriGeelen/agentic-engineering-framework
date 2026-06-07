# fw_tier0

> Integration tests for fw tier0 CLI.

**Type:** test | **Subsystem:** framework-core | **Location:** `tests/integration/fw_tier0.bats`

**Tags:** `bats`, `integration-test`, `tier0`, `cli`

## What It Does

Integration tests for fw tier0 subcommand
Tests the CLI interface for Tier 0 enforcement:
fw tier0          — show help
fw tier0 status   — show enforcement status

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_tier0.yaml`*
*Last verified: 2026-03-30*
