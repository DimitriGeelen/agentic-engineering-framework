# t5112_partial_complete_close

> T-5112: a partial-complete task (status work-completed, still in active/, an open ### Human box) is closed by re-running `fw task update <id> --status work-completed` — that is how a green reviewer verdict gets applied.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5112_partial_complete_close.bats`

## What It Does

T-5112: a partial-complete task (status work-completed, still in active/, an
open ### Human box) is closed by re-running `fw task update <id> --status
work-completed` — that is how a green reviewer verdict gets applied. The task
gate refused it as an edit under a completed task, so only the operator could
close (055 T-645, 2026-11-13). The allowance is exactly that command, for
exactly that task; everything else stays blocked.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5112_partial_complete_close.yaml`*
*Last verified: 2026-11-13*
