# compat

> Compatibility shims: bash 3.2 (macOS) POSIX-safe replacements for declare -A and other bashisms.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/compat.sh`

## What It Does

lib/compat.sh — Cross-platform compatibility helpers
Source this file to get portable shell functions that work on
both GNU (Linux) and BSD (macOS) systems.
Usage: source "$FRAMEWORK_ROOT/lib/compat.sh"

## Used By (24)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | sourced_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [paths](/docs/generated/lib-paths) | called_by | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [lib_compat](/docs/generated/tests-unit-lib_compat) | called-by | Unit tests for compat (7 tests) |
| [lib_compat](/docs/generated/tests-unit-lib_compat) | called_by | Unit tests for compat (7 tests) |
| [context_decision](/docs/generated/tests-unit-context_decision) | called_by | Unit tests for context decision (11 tests) |
| [context_decision](/docs/generated/tests-unit-context_decision) | tests_by | Unit tests for context decision (11 tests) |
| [context_episodic](/docs/generated/tests-unit-context_episodic) | called_by | Unit tests for context episodic (11 tests) |
| [context_episodic](/docs/generated/tests-unit-context_episodic) | tests_by | Unit tests for context episodic (11 tests) |
| [context_focus](/docs/generated/tests-unit-context_focus) | called_by | Unit tests for context focus (15 tests) |
| [context_focus](/docs/generated/tests-unit-context_focus) | tests_by | Unit tests for context focus (15 tests) |
| [context_learning](/docs/generated/tests-unit-context_learning) | called_by | Unit tests for context learning (10 tests) |
| [context_learning](/docs/generated/tests-unit-context_learning) | tests_by | Unit tests for context learning (10 tests) |
| [context_pattern](/docs/generated/tests-unit-context_pattern) | called_by | Unit tests for context pattern (11 tests) |
| [context_pattern](/docs/generated/tests-unit-context_pattern) | tests_by | Unit tests for context pattern (11 tests) |
| [context_status](/docs/generated/tests-unit-context_status) | called_by | Unit tests for context status (7 tests) |
| [context_status](/docs/generated/tests-unit-context_status) | tests_by | Unit tests for context status (7 tests) |
| [git_common](/docs/generated/tests-unit-git_common) | called_by | Unit tests for git common (10 tests) |
| [git_common](/docs/generated/tests-unit-git_common) | tests_by | Unit tests for git common (10 tests) |
| [lib_compat](/docs/generated/tests-unit-lib_compat) | tests_by | Unit tests for compat (7 tests) |
| [lib_update](/docs/generated/tests-unit-lib_update) | called_by | Unit tests for update (3 tests) |
| [lib_update](/docs/generated/tests-unit-lib_update) | tests_by | Unit tests for update (3 tests) |
| [lib_version](/docs/generated/tests-unit-lib_version) | called_by | Unit tests for version (16 tests) |
| [lib_version](/docs/generated/tests-unit-lib_version) | tests_by | Unit tests for version (16 tests) |

---
*Auto-generated from Component Fabric. Card: `lib-compat.yaml`*
*Last verified: 2026-03-09*
