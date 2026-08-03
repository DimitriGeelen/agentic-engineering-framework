# t2465_reanchor_from_cwd

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2465_reanchor_from_cwd.bats`

## What It Does

T-2465 — unit tests for lib/paths.sh:fw_reanchor_from_cwd (+ the hook-stdin
wrapper). This is the SHARED resolver generalized from T-2463's inline block:
every framework hook is wired by main's absolute path, so when it fires in a
worktree session bin/fw resolves PROJECT_ROOT to MAIN; the resolver re-anchors
to the project the tool actually ran in, read from the per-call stdin `cwd`.
Contract:
cwd resolves to a project root != PROJECT_ROOT → re-anchor PROJECT_ROOT +
TASKS_DIR + CONTEXT_DIR + _FW_PATHS_DERIVED_BY to it
cwd empty / not a dir / no project above / == PROJECT_ROOT → no-op

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [paths](/docs/generated/lib-paths) | tests | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2465_reanchor_from_cwd.yaml`*
*Last verified: 2026-06-23*
