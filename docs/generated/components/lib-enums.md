# enums

> Single source of truth for framework enumerations — valid statuses, workflow types, horizons, and status transitions. Provides is_valid_status(), is_valid_type(), is_valid_horizon(), is_valid_transition() functions. Replaces hardcoded lists previously duplicated across 6+ files.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/enums.sh`

**Tags:** `shell`, `enums`, `validation`, `core`

## What It Does

lib/enums.sh — Single source of truth for framework enumerations
Reads status-transitions.yaml and compiles to O(1) associative array lookup.
Falls back to inline definitions if YAML file or python3 unavailable.
Usage: source "$FRAMEWORK_ROOT/lib/enums.sh"

## Used By (6)

| Component | Relationship |
|-----------|-------------|
| `agents/task-create/create-task.sh` | calls |
| `agents/task-create/update-task.sh` | calls |
| `agents/task-create/create-task.sh` | called_by |
| `agents/task-create/update-task.sh` | called_by |
| `tests/unit/lib_enums.bats` | called-by |
| `tests/unit/lib_enums.bats` | called_by |

---
*Auto-generated from Component Fabric. Card: `lib-enums.yaml`*
*Last verified: 2026-03-10*
