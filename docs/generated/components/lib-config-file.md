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

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `lib/config-file.sh` | calls |

## Used By (6)

| Component | Relationship |
|-----------|-------------|
| `lib/config-file.sh` | called-by |
| `tests/unit/lib_config_file.bats` | called-by |
| `tests/integration/fw_config.bats` | tested_by |
| `lib/config-file.sh` | called_by |
| `tests/integration/fw_config.bats` | called_by |
| `tests/unit/lib_config_file.bats` | called_by |

## Related

### Tasks
- T-889: fw config set/get — read and write persistent settings in .framework.yaml
- T-907: Add validation for known settings in fw config set
- T-912: Add fw config overrides command — show all non-default settings

---
*Auto-generated from Component Fabric. Card: `lib-config-file.yaml`*
*Last verified: 2026-04-05*
