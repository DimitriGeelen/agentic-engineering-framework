# check_active_task_cwd_resolution

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/check_active_task_cwd_resolution.bats`

## What It Does

T-2463 (OBS-080) — the check-active-task gate must resolve PROJECT_ROOT from the
per-call `cwd` Claude Code passes on stdin, NOT from the hook's process cwd.
Why: in a git-worktree session the gate runs as <main>/bin/fw hook, and with
CLAUDE_PROJECT_DIR unset bin/fw resolves PROJECT_ROOT from the hook's process
cwd (the main launch dir). So the gate read MAIN's focus.yaml while the tool
actually ran in the worktree — worktree work blocked "No active task" whenever
main focus was null (confirmed live 2026-06-23). The fix re-anchors PROJECT_ROOT
+ path vars to the project root that stdin `cwd` resolves to.
Contract pinned (PROJECT_ROOT env simulates bin/fw resolving to the MAIN repo):
cwd=WTFIX  + WTFIX focus=active   → allowed (exit 0)  [re-anchored to worktree]

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-active-task](/docs/generated/agents-context-check-active-task) | calls | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [check-active-task](/docs/generated/agents-context-check-active-task) | tests | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-check_active_task_cwd_resolution.yaml`*
*Last verified: 2026-06-23*
