# note_exit_status

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/note_exit_status.bats`

## What It Does

T-2868 — `fw note` must exit 0 when it has written the note.
Origin: do_capture ended
[ -n "$task" ] && echo -e "  context: $task"
as its FINAL statement. With no focus task the test returns 1, `&&`
short-circuits, and 1 becomes the function's return value and the script's exit
status — after the note has been written and a success line printed.
A fresh project has no .context/working/focus.yaml until `fw context focus` runs,
so the FIRST `fw note` in every new project reported failure while succeeding.
It is a false red on a write: a caller that retries on non-zero duplicates the
observation, and anything under `set -e` aborts.

---
*Auto-generated from Component Fabric. Card: `tests-unit-note_exit_status.yaml`*
*Last verified: 2026-08-08*
