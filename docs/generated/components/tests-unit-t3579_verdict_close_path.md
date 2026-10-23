# t3579_verdict_close_path

> T-3579 — closing on an independent reviewer's green verdict is the NORMAL path.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3579_verdict_close_path.bats`

## What It Does

T-3579 — closing on an independent reviewer's green verdict is the NORMAL path.
Every step is the shipped code: `fw reviewer verdict record`, then update-task.sh
--status work-completed. No --skip-* flag, no FW_ALLOW_* variable anywhere in this
file — that absence is the assertion. A render-surface task with a human-owned taste
[REVIEW] criterion is the exact shape that took --skip-render-review +
FW_ALLOW_PARTIAL_COMPLETE_EDIT=1 seven times on 2026-09-29/30.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3579_verdict_close_path.yaml`*
*Last verified: 2026-09-30*
