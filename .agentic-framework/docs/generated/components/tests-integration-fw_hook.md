# fw_hook

> Integration tests for fw hook CLI.

**Type:** test | **Subsystem:** framework-core | **Location:** `tests/integration/fw_hook.bats`

**Tags:** `bats`, `integration-test`, `hook`, `cli`

## What It Does

Integration tests for fw hook subcommand

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_hook.yaml`*
*Last verified: 2026-03-30*
