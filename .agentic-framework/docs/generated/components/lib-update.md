# update

> fw update subcommand: CLI wrapper for framework self-update. Pulls latest, runs upgrade, reports changes.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/update.sh`

## What It Does

fw update - Update the framework (vendored or global)
Vendored projects (.agentic-framework/): clones upstream into temp dir,
re-vendors from there. Uses upstream_repo from .framework.yaml.
Global installs (~/.agentic-framework with .git): fetches and resets
to latest upstream (legacy path, pre-T-499).

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [lib_update](/docs/generated/tests-unit-lib_update) | called-by | Unit tests for update (3 tests) |
| [lib_update](/docs/generated/tests-unit-lib_update) | called_by | Unit tests for update (3 tests) |
| [lib_update](/docs/generated/tests-unit-lib_update) | tests_by | Unit tests for update (3 tests) |

## Related

### Tasks
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `lib-update.yaml`*
*Last verified: 2026-03-23*
