# fw_config

> Integration tests for fw config CLI (9 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/integration/fw_config.bats`

**Tags:** `config`, `bats`, `integration-test`

## What It Does

Integration tests for fw config subcommand
Origin: T-927

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [config-file](/docs/generated/lib-config-file) | calls | Reads and writes persistent project-level settings in .framework.yaml with round-trip YAML editing that preserves comments |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Related

### Tasks
- T-927: Add integration tests for fw config command

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_config.yaml`*
*Last verified: 2026-04-05*
