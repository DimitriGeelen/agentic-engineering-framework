# lib_config_file

> Unit tests for lib/config-file.sh — fw config set/get/list commands

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/lib_config_file.bats`

**Tags:** `config`, `bats`, `unit-test`

## What It Does

Unit tests for lib/config-file.sh — fw config set/get/list
Origin: T-896

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [config-file](/docs/generated/lib-config-file) | calls | Reads and writes persistent project-level settings in .framework.yaml with round-trip YAML editing that preserves comments |
| [config-file](/docs/generated/lib-config-file) | tests | Reads and writes persistent project-level settings in .framework.yaml with round-trip YAML editing that preserves comments |

## Related

### Tasks
- T-896: Add unit tests for lib/config-file.sh (fw config set/get/list)
- T-907: Add validation for known settings in fw config set
- T-926: Add tests for fw config overrides command

---
*Auto-generated from Component Fabric. Card: `tests-unit-lib_config_file.yaml`*
*Last verified: 2026-04-05*
