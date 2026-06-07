# enums

> Single source of truth for framework enumerations — valid statuses, workflow types, horizons, and status transitions. Provides is_valid_status(), is_valid_type(), is_valid_horizon(), is_valid_transition() functions. Replaces hardcoded lists previously duplicated across 6+ files.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/enums.sh`

**Tags:** `shell`, `enums`, `validation`, `core`

## What It Does

lib/enums.sh — Single source of truth for framework enumerations
Reads status-transitions.yaml and compiles to O(1) associative array lookup.
Falls back to inline definitions if YAML file or python3 unavailable.
Usage: source "$FRAMEWORK_ROOT/lib/enums.sh"

## Used By (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [create-task](/docs/generated/agents-task-create-create-task) | calls | Task Creation Agent - Mechanical Operations |
| [update-task](/docs/generated/agents-task-create-update-task) | calls | Task Update Agent - Status transitions with auto-triggers |
| [create-task](/docs/generated/agents-task-create-create-task) | called_by | Task Creation Agent - Mechanical Operations |
| [update-task](/docs/generated/agents-task-create-update-task) | called_by | Task Update Agent - Status transitions with auto-triggers |
| [lib_enums](/docs/generated/tests-unit-lib_enums) | called-by | Unit tests for enums (23 tests) |
| [lib_enums](/docs/generated/tests-unit-lib_enums) | called_by | Unit tests for enums (23 tests) |
| [lib_enums](/docs/generated/tests-unit-lib_enums) | tests_by | Unit tests for enums (23 tests) |
| [test_work_on_completed_task](/docs/generated/tests-unit-test_work_on_completed_task) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-enums.yaml`*
*Last verified: 2026-03-10*
