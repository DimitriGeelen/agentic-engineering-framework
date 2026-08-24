# check-active-completed-dup

> PreToolUse Write|Edit|MultiEdit guard (T-2121 prong 1) that blocks creating .tasks/completed/T-N while .tasks/active/T-N already exists (or vice-versa) — the T-2091 active/completed divergence class. Fires only on genuine file creation; git-mv completion path never reaches it. Blocks under agent control; override FW_ALLOW_ACTIVE_COMPLETED_DUP=1 (Tier-2 logged).

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-active-completed-dup.py`

**Tags:** `hook`, `pretooluse`, `task-integrity`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook_paths](/docs/generated/lib-hook_paths) | calls | TODO: describe what this component does |
| [hook_paths](/docs/generated/lib-hook_paths) | uses | TODO: describe what this component does |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-active-completed-dup-sh](/docs/generated/agents-context-check-active-completed-dup-sh) | triggers | Thin wrapper (T-2517) the fw hook dispatcher loads for the active/completed duplicate write-time guard. Execs check-active-completed-dup.py; the shell layer exists only because bin/fw's hook loader globs .sh files. |
| [hook-config](/docs/generated/hook-config) | renders | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [check-active-completed-dup-sh](/docs/generated/agents-context-check-active-completed-dup-sh) | called_by | Thin wrapper (T-2517) the fw hook dispatcher loads for the active/completed duplicate write-time guard. Execs check-active-completed-dup.py; the shell layer exists only because bin/fw's hook loader globs .sh files. |

---
*Auto-generated from Component Fabric. Card: `agents-context-check-active-completed-dup.yaml`*
*Last verified: 2026-07-10*
