# fw_doctor

> Integration tests for fw doctor CLI — 4 tests covering health check, installation, config, and status markers.

**Type:** test | **Subsystem:** framework-core | **Location:** `tests/integration/fw_doctor.bats`

**Tags:** `bats`, `integration-test`, `doctor`, `cli`

## What It Does

Integration tests for fw doctor subcommand
Tests the CLI interface for framework health check:
fw doctor — run all health checks

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_doctor.yaml`*
*Last verified: 2026-03-30*
