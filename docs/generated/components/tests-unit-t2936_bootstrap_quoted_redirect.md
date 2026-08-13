# t2936_bootstrap_quoted_redirect

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2936_bootstrap_quoted_redirect.bats`

## What It Does

T-2936 — the task gate refused both commands its own block message prescribes.
With focus null:
bin/fw task create --name "correct OBS-231 invalid-owner count 11->10 (...)" --start
→ BLOCKED: No active task. To unblock: 1. bin/fw task create ...
`check-active-task.sh` tested write-patterns before the task-bootstrap exemption
(T-2052, ~:198), and its own comment recorded the ordering as safe — "Reached only
when no write pattern is present". That holds only if a write pattern means a write.
`11->10` matches `[^2>&]>[^>&]` from INSIDE A QUOTED --name, so creating a task read
as a file write and was blocked for having no active task.
The deadlock is the point: creating the task is what would satisfy the gate, and the

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2936_bootstrap_quoted_redirect.yaml`*
*Last verified: 2026-08-12*
