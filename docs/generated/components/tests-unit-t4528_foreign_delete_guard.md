# t4528_foreign_delete_guard

> T-4528: commit-msg refuses a commit that deletes files last committed by a DIFFERENT task unless the message names that task.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4528_foreign_delete_guard.bats`

## What It Does

T-4528: commit-msg refuses a commit that deletes files last committed by a
DIFFERENT task unless the message names that task. Origin: 290e149d6 (T-3866)
committed from a scratch index built before eac91df2f (T-4520) and deleted
T-4520's six new files.
END-TO-END: installs the real hooks into a fixture repo and runs real
`git commit`s, two "workers" sharing one checkout.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4528_foreign_delete_guard.yaml`*
*Last verified: 2026-10-21*
