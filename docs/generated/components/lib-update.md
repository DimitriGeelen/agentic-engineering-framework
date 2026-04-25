# update

> fw update subcommand: CLI wrapper for framework self-update. Pulls latest, runs upgrade, reports changes.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/update.sh`

## What It Does

fw update - Update the framework (vendored or global)
Vendored projects (.agentic-framework/): clones upstream into temp dir,
re-vendors from there. Uses upstream_repo from .framework.yaml.
Global installs (~/.agentic-framework with .git): fetches and resets
to latest upstream (legacy path, pre-T-499).

## Used By (3)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |
| `tests/unit/lib_update.bats` | called-by |
| `tests/unit/lib_update.bats` | called_by |

## Related

### Tasks
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `lib-update.yaml`*
*Last verified: 2026-03-23*
