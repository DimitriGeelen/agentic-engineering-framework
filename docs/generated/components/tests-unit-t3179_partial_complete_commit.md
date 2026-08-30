# t3179_partial_complete_commit

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3179_partial_complete_commit.bats`

## What It Does

T-3179: partial-complete commit deadlock — the residual half of T-2054.
T-2054 allows `git commit` when focus is NULL, which is what a FULLY
completed task leaves behind (moved active/→completed/, focus nulled).
A PARTIAL-complete task never reaches that state. An unchecked ### Human AC
flips status to work-completed while the file STAYS in active/ and focus
keeps pointing at it — so CURRENT_TASK is non-empty, the status switch is
reached, and the task's own verified work cannot be committed under its own
ID. That is the common case, not an edge one: P-013 steers every
render-touching build task into partial-complete by design.
The allowance must be SCOPED. Three things have to stay true, and each has

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3179_partial_complete_commit.yaml`*
*Last verified: 2026-08-26*
