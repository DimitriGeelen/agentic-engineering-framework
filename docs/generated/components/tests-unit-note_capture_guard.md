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

---
*Auto-generated from Component Fabric. Card: `tests-unit-note_capture_guard.yaml`*
*Last verified: 2026-08-08*
