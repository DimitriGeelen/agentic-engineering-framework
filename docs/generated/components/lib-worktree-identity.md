# worktree-identity

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/worktree-identity.sh`

## What It Does

lib/worktree-identity.sh — "is this checkout a replica?" (T-3111, R7)
ONE PREDICATE, THREE SURFACES. The question *am I a linked worktree* is asked by:
1. lib/paths.sh            — sources this file, so every agent that sources
paths.sh keeps `fw_is_linked_worktree` verbatim.
2. bin/fw's L2 redirect    — must answer it BEFORE FRAMEWORK_ROOT exists, and
cannot source paths.sh (which resolves and exports
paths as a side effect of being sourced).
3. bin/fw doctor           — suppresses HOST-level drift checks in a worktree
(T-2435/OBS-077); previously an inline copy.
The predicate lived in lib/paths.sh with an independent inline copy in bin/fw's

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [t3111_worktree_reexec](/docs/generated/tests-unit-t3111_worktree_reexec) | tests_by | TODO: describe what this component does |
| [paths](/docs/generated/lib-paths) | called_by | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [t3111_worktree_reexec](/docs/generated/tests-unit-t3111_worktree_reexec) | called_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-worktree-identity.yaml`*
*Last verified: 2026-08-22*
