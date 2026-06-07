# lib_validate_init

> Unit tests for lib/validate-init.sh (7 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/lib_validate_init.bats`

**Tags:** `lib-validate-init`, `bats`, `unit-test`

## What It Does

Unit tests for lib/validate-init.sh (fw validate-init)
Origin: T-945

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [validate-init](/docs/generated/lib-validate-init) | calls | Post-init validation — reads #@init: tags from init.sh and validates each creation unit exists and is correct. Called automatically at end of fw init and available as fw validate-init. |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [validate-init](/docs/generated/lib-validate-init) | tests | Post-init validation — reads #@init: tags from init.sh and validates each creation unit exists and is correct. Called automatically at end of fw init and available as fw validate-init. |
| [paths](/docs/generated/lib-paths) | tests | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |

## Related

### Tasks
- T-945: Unit tests for untested lib scripts — ask.sh, first-run.sh, validate-init.sh

---
*Auto-generated from Component Fabric. Card: `tests-unit-lib_validate_init.yaml`*
*Last verified: 2026-04-06*
