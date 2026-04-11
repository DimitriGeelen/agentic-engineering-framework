# validate-init

> Post-init validation — reads #@init: tags from init.sh and validates each creation unit exists and is correct. Called automatically at end of fw init and available as fw validate-init.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/validate-init.sh`

**Tags:** `init`, `validation`, `governance`

## What It Does

fw validate-init — Verify fw init produced correct and complete output
Reads #@init: tags from lib/init.sh and validates each against target directory
Tag format in init.sh:
@init: <type>-<key> <path> [check_args] [?condition]
Human-readable description
Check types: dir, file, yaml, json, exec, hookpaths
Conditions: ?git (requires .git), ?claude,generic (provider match)

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `lib/init.sh` | reads |

## Used By (4)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |
| `lib/init.sh` | called_by |
| `tests/unit/lib_validate_init.bats` | called-by |
| `tests/unit/lib_validate_init.bats` | called_by |

## Related

### Tasks
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `lib-validate-init.yaml`*
*Last verified: 2026-03-08*
