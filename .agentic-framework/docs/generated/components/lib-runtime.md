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

| Target | Relationship |
|--------|-------------|
| `lib/runtime.sh` | calls |

## Used By (4)

| Component | Relationship |
|-----------|-------------|
| `lib/runtime.sh` | called-by |
| `tests/unit/lib_runtime.bats` | called-by |
| `lib/runtime.sh` | called_by |
| `tests/unit/lib_runtime.bats` | called_by |

---
*Auto-generated from Component Fabric. Card: `lib-runtime.yaml`*
*Last verified: 2026-03-27*
