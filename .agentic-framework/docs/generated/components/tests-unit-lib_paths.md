# lib_paths

> Unit tests for paths (5 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/lib_paths.bats`

**Tags:** `paths`, `bats`, `unit-test`

## What It Does

Unit tests for lib/paths.sh
Tests path resolution: FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [paths](/docs/generated/lib-paths) | tests | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-lib_paths.yaml`*
*Last verified: 2026-04-05*
