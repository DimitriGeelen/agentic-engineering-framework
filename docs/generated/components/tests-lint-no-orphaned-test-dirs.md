# no-orphaned-test-dirs

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/lint/no-orphaned-test-dirs.bats`

## What It Does

T-2697 — every tests/<dir>/ holding .bats files must be reachable from a runner.
Origin: tests/lint/ held 7 invariant test files and was globbed by NO runner
from creation until 2026-07-31. Seven of its tests were red, one since
2026-06-10, and nothing said so. The verb that looks like it runs them —
`fw test lint` — runs shellcheck, so its green output actively reassured.
The failure class is the one this whole directory exists to catch: a guard
that reports success by not running. Directory-level, so it applies to the
next tests/<thing>/ someone adds as well as to the ones here today.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-lint-no-orphaned-test-dirs.yaml`*
*Last verified: 2026-07-31*
