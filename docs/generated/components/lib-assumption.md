# assumption

> fw assumption - Assumption tracking

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/assumption.sh`

## What It Does

fw assumption - Assumption tracking
Manages project assumptions: register, validate, invalidate, list

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [lib_assumption](/docs/generated/tests-unit-lib_assumption) | called-by | Unit tests for assumption (11 tests) |
| [lib_assumption](/docs/generated/tests-unit-lib_assumption) | called_by | Unit tests for assumption (11 tests) |
| [lib_assumption](/docs/generated/tests-unit-lib_assumption) | tests_by | Unit tests for assumption (11 tests) |

---
*Auto-generated from Component Fabric. Card: `lib-assumption.yaml`*
*Last verified: 2026-02-20*
