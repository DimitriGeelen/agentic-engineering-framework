# fw_validate_init

> Integration tests for fw validate_init CLI.

**Type:** test | **Subsystem:** framework-core | **Location:** `tests/integration/fw_validate_init.bats`

**Tags:** `bats`, `integration-test`, `validate_init`, `cli`

## What It Does

Integration tests for fw validate-init subcommand

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_validate_init.yaml`*
*Last verified: 2026-03-30*
