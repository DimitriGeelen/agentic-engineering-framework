# t5117_close_prints_not_applied

> T-5117: the close (and the partial-complete re-run, which calls the same function) prints a verdict that exists but does not count.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5117_close_prints_not_applied.bats`

## What It Does

T-5117: the close (and the partial-complete re-run, which calls the same function)
prints a verdict that exists but does not count. Exercises update-task.sh's own
apply_reviewer_verdicts against a stub verdict_ledger.py, so only the shell side
is under test here (the Python side: t5117_not_applied_test.py).

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5117_close_prints_not_applied.yaml`*
*Last verified: 2026-11-13*
