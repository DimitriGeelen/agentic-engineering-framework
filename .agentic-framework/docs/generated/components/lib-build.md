# build

> fw build subcommand: placeholder for future build orchestration. Currently unused.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/build.sh`

## What It Does

Compile all TypeScript sources to JavaScript via esbuild
Called by: fw build, fw update, stale-guard in hooks

## Used By (3)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |
| `tests/unit/lib_build.bats` | called-by |
| `tests/unit/lib_build.bats` | called_by |

---
*Auto-generated from Component Fabric. Card: `lib-build.yaml`*
*Last verified: 2026-03-27*
