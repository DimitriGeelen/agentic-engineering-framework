# t5118_finalised_closure_commit

> T-5118 (055 T-645, msg a56f7da3) — the closure commit of a task that sat partial-complete.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5118_finalised_closure_commit.bats`

## What It Does

T-5118 (055 T-645, msg a56f7da3) — the closure commit of a task that sat partial-complete.
A partial-complete task gets date_finished at its FIRST transition to work-completed and is
finalised later (the same-status re-run that moves it to completed/). The T-4182 closure-commit
window measured only date_finished, so a task finalised a day after it went partial-complete
had its closure commit refused while focus sat on another task. Finalisation now records
date_finalised, and the window measures from the later of the two.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5118_finalised_closure_commit.yaml`*
*Last verified: 2026-11-13*
