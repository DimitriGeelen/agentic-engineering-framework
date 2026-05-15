# compat

> Compatibility shims: bash 3.2 (macOS) POSIX-safe replacements for declare -A and other bashisms.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/compat.sh`

## What It Does

lib/compat.sh — Cross-platform compatibility helpers
Source this file to get portable shell functions that work on
both GNU (Linux) and BSD (macOS) systems.
Usage: source "$FRAMEWORK_ROOT/lib/compat.sh"

## Used By (24)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | sourced_by |
| `bin/fw` | called_by |
| `lib/paths.sh` | called_by |
| `tests/unit/lib_compat.bats` | called-by |
| `tests/unit/lib_compat.bats` | called_by |
| `tests/unit/context_decision.bats` | called_by |
| `tests/unit/context_decision.bats` | tests_by |
| `tests/unit/context_episodic.bats` | called_by |
| `tests/unit/context_episodic.bats` | tests_by |
| `tests/unit/context_focus.bats` | called_by |
| `tests/unit/context_focus.bats` | tests_by |
| `tests/unit/context_learning.bats` | called_by |
| `tests/unit/context_learning.bats` | tests_by |
| `tests/unit/context_pattern.bats` | called_by |
| `tests/unit/context_pattern.bats` | tests_by |
| `tests/unit/context_status.bats` | called_by |
| `tests/unit/context_status.bats` | tests_by |
| `tests/unit/git_common.bats` | called_by |
| `tests/unit/git_common.bats` | tests_by |
| `tests/unit/lib_compat.bats` | tests_by |
| `tests/unit/lib_update.bats` | called_by |
| `tests/unit/lib_update.bats` | tests_by |
| `tests/unit/lib_version.bats` | called_by |
| `tests/unit/lib_version.bats` | tests_by |

---
*Auto-generated from Component Fabric. Card: `lib-compat.yaml`*
*Last verified: 2026-03-09*
