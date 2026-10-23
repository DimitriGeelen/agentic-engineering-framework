# t4115_task_stale_readonly

> T-4115: `fw task stale` is a read-only listing (bin/fw `stale)` arm reads .tasks/active/ and writes nothing), and fw doctor's Task-debt WARN says "Run: fw task stale" — so the task gate must not refuse it at null focus.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4115_task_stale_readonly.bats`

## What It Does

T-4115: `fw task stale` is a read-only listing (bin/fw `stale)` arm reads
.tasks/active/ and writes nothing), and fw doctor's Task-debt WARN says
"Run: fw task stale" — so the task gate must not refuse it at null focus.
Mutating `fw task` sub-verbs must still reach the gate.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4115_task_stale_readonly.yaml`*
*Last verified: 2026-10-20*
