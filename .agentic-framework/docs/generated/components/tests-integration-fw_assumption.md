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

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_assumption.yaml`*
*Last verified: 2026-03-30*
