# t5340_handover_no_dirty_task

> T-5340 — the handover auto-commit must not leave the handover task file dirty.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5340_handover_no_dirty_task.bats`

## What It Does

T-5340 — the handover auto-commit must not leave the handover task file dirty.
commit.sh bumps `last_update:` AFTER a pathspec-scoped commit (T-3090 order),
so the bump is never in the commit and the task file stays modified. The
handover commits with a pathspec, so every handover left its task dirty.
Fix: FW_COMMIT_SKIP_TASK_BUMP=1 skips that bump; handover.sh sets it on its
own commit only.
Hermetic: throwaway repos under $BATS_TEST_TMPDIR, hooks off, no push.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5340_handover_no_dirty_task.yaml`*
*Last verified: 2026-11-21*
