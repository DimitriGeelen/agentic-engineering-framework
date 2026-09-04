# check-arc-id

> TODO: describe what this component does

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-arc-id.py`

## What It Does

T-2468: resolve lib/ to import the shared hook project-root resolver

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook_paths](/docs/generated/lib-hook_paths) | calls | TODO: describe what this component does |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [hook_paths](/docs/generated/lib-hook_paths) | uses | TODO: describe what this component does |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-active-completed-dup](/docs/generated/agents-context-check-active-completed-dup) | called_by | PreToolUse Write\|Edit\|MultiEdit guard (T-2121 prong 1) that blocks creating .tasks/completed/T-N while .tasks/active/T-N already exists (or vice-versa) — the T-2091 active/completed divergence class. Fires only on genuine file creation; git-mv completion path never reaches it. Blocks under agent control; override FW_ALLOW_ACTIVE_COMPLETED_DUP=1 (Tier-2 logged). |
| [check-arc-id](/docs/generated/agents-context-check-arc-id) | called_by | TODO: describe what this component does |
| [check-inception-decisions](/docs/generated/agents-context-check-inception-decisions-py) | called_by | TODO: describe what this component does |
| [arc_id_validation_guard](/docs/generated/tests-unit-arc_id_validation_guard) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `agents-context-check-arc-id-py.yaml`*
*Last verified: 2026-09-03*
