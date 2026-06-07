# fw_audit

> Integration tests for fw audit CLI — 3 tests covering help, section run, and YAML output.

**Type:** test | **Subsystem:** framework-core | **Location:** `tests/integration/fw_audit.bats`

**Tags:** `bats`, `integration-test`, `audit`, `cli`

## What It Does

Integration tests for fw audit subcommand
Tests the CLI interface for compliance audit:
fw audit                — run all audit sections
fw audit --section X    — run specific section
fw audit --help         — show help

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_audit.yaml`*
*Last verified: 2026-03-30*
