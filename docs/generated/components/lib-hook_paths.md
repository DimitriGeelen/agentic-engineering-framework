# hook_paths

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/hook_paths.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-active-completed-dup](/docs/generated/agents-context-check-active-completed-dup) | called_by | PreToolUse Write\|Edit\|MultiEdit guard (T-2121 prong 1) that blocks creating .tasks/completed/T-N while .tasks/active/T-N already exists (or vice-versa) — the T-2091 active/completed divergence class. Fires only on genuine file creation; git-mv completion path never reaches it. Blocks under agent control; override FW_ALLOW_ACTIVE_COMPLETED_DUP=1 (Tier-2 logged). |
| [check-active-completed-dup](/docs/generated/agents-context-check-active-completed-dup) | uses_by | PreToolUse Write\|Edit\|MultiEdit guard (T-2121 prong 1) that blocks creating .tasks/completed/T-N while .tasks/active/T-N already exists (or vice-versa) — the T-2091 active/completed divergence class. Fires only on genuine file creation; git-mv completion path never reaches it. Blocks under agent control; override FW_ALLOW_ACTIVE_COMPLETED_DUP=1 (Tier-2 logged). |

---
*Auto-generated from Component Fabric. Card: `lib-hook_paths.yaml`*
*Last verified: 2026-07-07*
