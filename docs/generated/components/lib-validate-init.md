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

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [init](/docs/generated/lib-init) | reads | fw init - Bootstrap a new project with the Agentic Engineering Framework |
| [git-identity](/docs/generated/lib-git-identity) | calls | TODO: describe what this component does |

## Used By (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [init](/docs/generated/lib-init) | called_by | fw init - Bootstrap a new project with the Agentic Engineering Framework |
| [lib_validate_init](/docs/generated/tests-unit-lib_validate_init) | called-by | Unit tests for lib/validate-init.sh (7 tests) |
| [lib_validate_init](/docs/generated/tests-unit-lib_validate_init) | called_by | Unit tests for lib/validate-init.sh (7 tests) |
| [lib_validate_init](/docs/generated/tests-unit-lib_validate_init) | tests_by | Unit tests for lib/validate-init.sh (7 tests) |
| [git_identity_check](/docs/generated/tests-unit-git_identity_check) | tests_by | TODO: describe what this component does |
| [validate_init_hook_path_expansion](/docs/generated/tests-unit-validate_init_hook_path_expansion) | tests_by | TODO: describe what this component does |

## Related

### Tasks
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `lib-validate-init.yaml`*
*Last verified: 2026-03-08*
