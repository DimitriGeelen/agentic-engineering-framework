# note_capture_guard

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/note_capture_guard.bats`

## What It Does

T-2867 — `fw note` must refuse arguments it cannot use, never discard them.
Origin: observe.sh's dispatch ends `*) do_capture "$@"`, so any word that is not
a known sub-verb becomes the note text; and do_capture's option loop ended
`*) shift`, dropping every remaining positional on the floor. Composed:
fw note add "a real observation"
captured the word `add`, discarded the observation, exited 0, and printed the
wrong text back as confirmation. Measured cost before the fix: 26 of 191
observations were bare sub-verbs (add x16, resolve x6, show x3, status x1) —
26 notes someone meant to record and lost. 25 had already been triaged, so the
corpus had been read by a human twenty-five times without the shape registering.

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [observe](/docs/generated/agents-observe-observe) | calls | Observe Agent - Lightweight observation capture |
| [observe](/docs/generated/agents-observe-observe) | tests | Observe Agent - Lightweight observation capture |
| [paths](/docs/generated/lib-paths) | tests | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-note_capture_guard.yaml`*
*Last verified: 2026-08-08*
