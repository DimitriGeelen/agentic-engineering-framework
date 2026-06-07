# fw_onboarding

> Integration tests for fw onboarding CLI.

**Type:** test | **Subsystem:** framework-core | **Location:** `tests/integration/fw_onboarding.bats`

**Tags:** `bats`, `integration-test`, `onboarding`, `cli`

## What It Does

Integration tests for fw onboarding subcommand

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_onboarding.yaml`*
*Last verified: 2026-03-30*
