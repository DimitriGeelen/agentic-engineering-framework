# runtime

> Runtime environment detection: OS type, shell version, Python availability, brew/apt package manager resolution.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/runtime.sh`

## What It Does

Runtime detection: TypeScript (Node.js) with Python fallback
Source this file to use fw_run_ts()
Usage:
source "$FRAMEWORK_ROOT/lib/runtime.sh"
fw_run_ts "fw-util" yaml-get "$file" "$key"

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [runtime](/docs/generated/lib-runtime) | calls | Runtime environment detection: OS type, shell version, Python availability, brew/apt package manager resolution. |

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [runtime](/docs/generated/lib-runtime) | called-by | Runtime environment detection: OS type, shell version, Python availability, brew/apt package manager resolution. |
| [lib_runtime](/docs/generated/tests-unit-lib_runtime) | called-by | Unit tests for runtime (5 tests) |
| [runtime](/docs/generated/lib-runtime) | called_by | Runtime environment detection: OS type, shell version, Python availability, brew/apt package manager resolution. |
| [lib_runtime](/docs/generated/tests-unit-lib_runtime) | called_by | Unit tests for runtime (5 tests) |
| [lib_runtime](/docs/generated/tests-unit-lib_runtime) | tests_by | Unit tests for runtime (5 tests) |

---
*Auto-generated from Component Fabric. Card: `lib-runtime.yaml`*
*Last verified: 2026-03-27*
