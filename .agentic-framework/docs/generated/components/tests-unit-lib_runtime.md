# lib_runtime

> Unit tests for runtime (5 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/lib_runtime.bats`

**Tags:** `runtime`, `bats`, `unit-test`

## What It Does

Unit tests for lib/runtime.sh
Tests fw_run_ts() — TypeScript/Python runtime fallback

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [runtime](/docs/generated/lib-runtime) | calls | Runtime environment detection: OS type, shell version, Python availability, brew/apt package manager resolution. |
| [runtime](/docs/generated/lib-runtime) | tests | Runtime environment detection: OS type, shell version, Python availability, brew/apt package manager resolution. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-lib_runtime.yaml`*
*Last verified: 2026-04-05*
