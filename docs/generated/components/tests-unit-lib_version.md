# lib_version

> Unit tests for version (16 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/lib_version.bats`

**Tags:** `version`, `bats`, `unit-test`

## What It Does

Unit tests for lib/version.sh
Tests _read_fw_version(), do_version_bump (dry-run), do_version_check

## Dependencies (8)

| Target | Relationship |
|--------|-------------|
| `lib/version.sh` | calls |
| `lib/colors.sh` | calls |
| `lib/compat.sh` | calls |
| `lib/errors.sh` | calls |
| `lib/version.sh` | tests |
| `lib/colors.sh` | tests |
| `lib/compat.sh` | tests |
| `lib/errors.sh` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-lib_version.yaml`*
*Last verified: 2026-04-05*
