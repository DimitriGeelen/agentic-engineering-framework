# fw_promote

> Integration tests for fw promote CLI.

**Type:** test | **Subsystem:** framework-core | **Location:** `tests/integration/fw_promote.bats`

**Tags:** `bats`, `integration-test`, `promote`, `cli`

## What It Does

Integration tests for fw promote subcommand
Tests the CLI interface for the graduation pipeline:
fw promote           — show help
fw promote suggest   — show promotion candidates
fw promote status    — show all learnings with counts

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_promote.yaml`*
*Last verified: 2026-03-30*
