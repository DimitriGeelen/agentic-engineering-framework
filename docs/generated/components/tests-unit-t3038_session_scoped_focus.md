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

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3038_session_scoped_focus.yaml`*
*Last verified: 2026-08-16*
