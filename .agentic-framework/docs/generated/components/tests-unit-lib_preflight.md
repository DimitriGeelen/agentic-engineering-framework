# lib_preflight

> Unit tests for preflight (11 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/lib_preflight.bats`

**Tags:** `preflight`, `bats`, `unit-test`

## What It Does

Unit tests for lib/preflight.sh
Tests detect_pkg_manager(), individual check functions, and do_preflight --quiet

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [preflight](/docs/generated/lib-preflight) | calls | fw preflight subcommand. Validates system prerequisites (bash version, git version, python3, PyYAML) before framework operations. |
| [preflight](/docs/generated/lib-preflight) | tests | fw preflight subcommand. Validates system prerequisites (bash version, git version, python3, PyYAML) before framework operations. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-lib_preflight.yaml`*
*Last verified: 2026-04-05*
