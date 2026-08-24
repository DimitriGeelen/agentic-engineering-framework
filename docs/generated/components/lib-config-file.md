# config-file

> Reads and writes persistent project-level settings in .framework.yaml with round-trip YAML editing that preserves comments

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/config-file.sh`

## What It Does

lib/config-file.sh — Read/write persistent settings in .framework.yaml
Provides fw config set/get/list for project-level configuration.
Uses Python + ruamel.yaml for round-trip YAML editing (preserves comments).
Usage:
source "$FRAMEWORK_ROOT/lib/config-file.sh"
do_config set watchtower.port 3001
do_config get watchtower.port
do_config list
Origin: T-889 (foundation for T-885 service registry)

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [config-file](/docs/generated/lib-config-file) | calls | Reads and writes persistent project-level settings in .framework.yaml with round-trip YAML editing that preserves comments |
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |

## Used By (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [config-file](/docs/generated/lib-config-file) | called-by | Reads and writes persistent project-level settings in .framework.yaml with round-trip YAML editing that preserves comments |
| [lib_config_file](/docs/generated/tests-unit-lib_config_file) | called-by | Unit tests for lib/config-file.sh — fw config set/get/list commands |
| [fw_config](/docs/generated/tests-integration-fw_config) | tested_by | Integration tests for fw config CLI (9 tests) |
| [config-file](/docs/generated/lib-config-file) | called_by | Reads and writes persistent project-level settings in .framework.yaml with round-trip YAML editing that preserves comments |
| [fw_config](/docs/generated/tests-integration-fw_config) | called_by | Integration tests for fw config CLI (9 tests) |
| [lib_config_file](/docs/generated/tests-unit-lib_config_file) | called_by | Unit tests for lib/config-file.sh — fw config set/get/list commands |
| [lib_config_file](/docs/generated/tests-unit-lib_config_file) | tests_by | Unit tests for lib/config-file.sh — fw config set/get/list commands |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Related

### Tasks
- T-889: fw config set/get — read and write persistent settings in .framework.yaml
- T-907: Add validation for known settings in fw config set
- T-912: Add fw config overrides command — show all non-default settings

---
*Auto-generated from Component Fabric. Card: `lib-config-file.yaml`*
*Last verified: 2026-04-05*
