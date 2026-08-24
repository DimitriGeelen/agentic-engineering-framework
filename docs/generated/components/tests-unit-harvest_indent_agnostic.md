# harvest_indent_agnostic

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/harvest_indent_agnostic.bats`

## What It Does

T-2676 — harvest.sh indent-agnostic entry greps (dead learnings/patterns
sub-stages). Third instance of the indentation-assumption class (T-2672
resolve.sh emit-indent, 832 T-295 field report). The old greps matched only
'^    learning:' / '^    pattern:' (4-space) while the live capture path
writes 2-space field lines under column-0 list items — harvest_learnings
was a permanent no-op ("No learnings found in project").

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [harvest](/docs/generated/lib-harvest) | calls | fw harvest - Collect learnings from projects back into the framework |
| [paths](/docs/generated/lib-paths) | tests | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [harvest](/docs/generated/lib-harvest) | tests | fw harvest - Collect learnings from projects back into the framework |

---
*Auto-generated from Component Fabric. Card: `tests-unit-harvest_indent_agnostic.yaml`*
*Last verified: 2026-07-29*
