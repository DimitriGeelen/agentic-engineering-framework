# fw_practices

> Integration tests for fw practices CLI.

**Type:** test | **Subsystem:** framework-core | **Location:** `tests/integration/fw_practices.bats`

**Tags:** `bats`, `integration-test`, `practices`, `cli`

## What It Does

Integration tests for fw practices subcommand

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_practices.yaml`*
*Last verified: 2026-03-30*
