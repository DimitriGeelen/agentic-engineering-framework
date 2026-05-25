# build

> fw build subcommand: placeholder for future build orchestration. Currently unused.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/build.sh`

## What It Does

Compile all TypeScript sources to JavaScript via esbuild
Called by: fw build, fw update, stale-guard in hooks

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [lib_build tests](/docs/generated/tests-unit-lib_build) | called-by | 7 bats unit tests for lib/build.sh — early exits, stale guard, build detection (T-811) |
| [lib_build tests](/docs/generated/tests-unit-lib_build) | called_by | 7 bats unit tests for lib/build.sh — early exits, stale guard, build detection (T-811) |
| [lib_build tests](/docs/generated/tests-unit-lib_build) | tests_by | 7 bats unit tests for lib/build.sh — early exits, stale guard, build detection (T-811) |

---
*Auto-generated from Component Fabric. Card: `lib-build.yaml`*
*Last verified: 2026-03-27*
