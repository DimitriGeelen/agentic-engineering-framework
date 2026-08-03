# check-active-completed-dup-sh

> Thin wrapper (T-2517) the fw hook dispatcher loads for the active/completed duplicate write-time guard. Execs check-active-completed-dup.py; the shell layer exists only because bin/fw's hook loader globs .sh files.

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-active-completed-dup.sh`

**Tags:** `hook`, `pretooluse`, `wrapper`

## What It Does

T-2517: active/completed same-id task duplicate write-time guard (T-2121 prong 1).
The fw hook dispatcher (bin/fw) loads .sh files; the actual logic lives in
check-active-completed-dup.py to keep the file-glob + YAML-adjacent parsing clean.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-active-completed-dup](/docs/generated/agents-context-check-active-completed-dup) | calls | PreToolUse Write\|Edit\|MultiEdit guard (T-2121 prong 1) that blocks creating .tasks/completed/T-N while .tasks/active/T-N already exists (or vice-versa) — the T-2091 active/completed divergence class. Fires only on genuine file creation; git-mv completion path never reaches it. Blocks under agent control; override FW_ALLOW_ACTIVE_COMPLETED_DUP=1 (Tier-2 logged). |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | triggers | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [hook-config](/docs/generated/hook-config) | called_by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |

---
*Auto-generated from Component Fabric. Card: `agents-context-check-active-completed-dup-sh.yaml`*
*Last verified: 2026-07-10*
