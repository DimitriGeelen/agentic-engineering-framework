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

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [observe](/docs/generated/agents-observe-observe) | calls | Observe Agent - Lightweight observation capture |
| [observe](/docs/generated/agents-observe-observe) | tests | Observe Agent - Lightweight observation capture |
| [paths](/docs/generated/lib-paths) | tests | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-note_exit_status.yaml`*
*Last verified: 2026-08-08*
