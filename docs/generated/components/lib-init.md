# init

> fw init - Bootstrap a new project with the Agentic Engineering Framework

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/init.sh`

## What It Does

fw init - Bootstrap a new project with the Agentic Engineering Framework
Creates the directory structure, config files, and git hooks needed
for a project to use the framework.

## Dependencies (4)

| Target | Relationship |
|--------|-------------|
| `agents/git/git.sh` | calls |
| `lib/validate-init.sh` | calls |
| `lib/preflight.sh` | calls |
| `C-001` | calls |

## Used By (7)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |
| `lib/setup.sh` | called_by |
| `lib/validate-init.sh` | reads_tags |
| `lib/upstream.sh` | read_by |
| `lib/validate-init.sh` | read_by |
| `tests/unit/lib_init.bats` | called-by |
| `tests/unit/lib_init.bats` | called_by |

## Related

### Tasks
- T-796: Fix remaining single-warning shellcheck issues in agent scripts
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes
- T-850: Fix session metrics — per-session deltas instead of cumulative transcript analysis
- T-855: Sync vendored .agentic-framework/ with T-849 through T-854 fixes

---
*Auto-generated from Component Fabric. Card: `lib-init.yaml`*
*Last verified: 2026-02-20*
