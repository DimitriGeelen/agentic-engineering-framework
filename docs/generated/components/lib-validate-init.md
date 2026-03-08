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

## Related

### Tasks
- T-357: Implement post-init validation with #@init: tags

---
*Auto-generated from Component Fabric. Card: `lib-validate-init.yaml`*
*Last verified: 2026-03-08*
