# fw_init

> Integration tests for fw init CLI.

**Type:** test | **Subsystem:** framework-core | **Location:** `tests/integration/fw_init.bats`

**Tags:** `bats`, `integration-test`, `init`, `cli`

## What It Does

Integration tests for fw init subcommand
Tests framework initialization in a fresh directory.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_init.yaml`*
*Last verified: 2026-03-30*
