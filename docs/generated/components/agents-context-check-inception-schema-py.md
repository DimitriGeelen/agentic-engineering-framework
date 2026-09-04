# check-inception-schema

> TODO: describe what this component does

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-inception-schema.py`

## What It Does

T-2468: resolve lib/ to import the shared hook project-root resolver
(parity with lib/paths.sh:fw_reanchor_from_cwd — re-anchor to the worktree).

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook_paths](/docs/generated/lib-hook_paths) | calls | TODO: describe what this component does |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [hook_paths](/docs/generated/lib-hook_paths) | uses | TODO: describe what this component does |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-inception-schema](/docs/generated/agents-context-check-inception-schema) | called_by | TODO: describe what this component does |
| [check_inception_schema](/docs/generated/tests-unit-check_inception_schema) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `agents-context-check-inception-schema-py.yaml`*
*Last verified: 2026-09-03*
