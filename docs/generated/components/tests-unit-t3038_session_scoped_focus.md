# t3038_session_scoped_focus

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3038_session_scoped_focus.bats`

## What It Does

T-3038 (OBS-291) — focus is per-session, not per-project, for dispatched workers.
The bug this pins is a LOCKOUT, not a lost write. `fw context focus` stamps
`focus_session` next to `current_task` in ONE shared file, and the task gate
refuses every Write and every Bash — read-only ls/cat/grep included — when that
stamp does not match the running session. So a dispatched worker calling
`fw work-on` did not merely change a value: it locked the parent out of its own
unrelated work, and re-asserting focus only held until the next worker ran.
Three properties are load-bearing and each is pinned below:
1. DEFAULT UNCHANGED — with FW_SESSION_SCOPED_FOCUS unset, every path
resolves to the shared focus.yaml exactly as before. This is what makes

## Dependencies (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [check-active-task](/docs/generated/agents-context-check-active-task) | calls | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [focus](/docs/generated/agents-context-lib-focus) | calls | Context Agent - focus command |
| [termlink](/docs/generated/agents-termlink-termlink) | calls | TermLink integration wrapper: spawn, exec, dispatch, cleanup, status. Adds task-tagging and budget checks around the termlink binary. |
| [paths](/docs/generated/lib-paths) | tests | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [check-active-task](/docs/generated/agents-context-check-active-task) | tests | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [focus](/docs/generated/agents-context-lib-focus) | tests | Context Agent - focus command |
| [termlink](/docs/generated/agents-termlink-termlink) | tests | TermLink integration wrapper: spawn, exec, dispatch, cleanup, status. Adds task-tagging and budget checks around the termlink binary. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3038_session_scoped_focus.yaml`*
*Last verified: 2026-08-16*
