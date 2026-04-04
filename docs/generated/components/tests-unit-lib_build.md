# lib_build tests

> 7 bats unit tests for lib/build.sh — early exits, stale guard, build detection (T-811)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/lib_build.bats`

**Tags:** `typescript`, `build`, `testing`

## What It Does

Unit tests for lib/build.sh — TypeScript compilation via esbuild
Tests: early exits (no src, no .ts), stale guard, verbose flag, npx missing

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `lib/build.sh` | calls |

## Related

### Tasks
- T-811: Unit tests for lib/build.sh TypeScript compilation

---
*Auto-generated from Component Fabric. Card: `tests-unit-lib_build.yaml`*
*Last verified: 2026-04-03*
