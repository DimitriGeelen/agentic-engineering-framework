# audit_ctl012_missing_decide_grandfather

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/audit_ctl012_missing_decide_grandfather.bats`

## What It Does

T-2385: CTL-012-MISSING-DECIDE grandfather cutoff regression.
RCA finding: T-1902/T-2000/T-1915/T-1905 were flagged as
"flipped without decide ceremony" but git archaeology proved each was
moved into .tasks/completed/ as a silent git-mv side-effect of an
unrelated commit (the L-390 pattern) — weeks BEFORE the
CTL-012-MISSING-DECIDE classifier itself existed (T-2202, shipped
2026-06-13). The detector cannot have caught something it didn't exist
to catch; re-flagging these forever adds no actionable signal, since the
flip path is already closed for NEW instances by CTL-028 (T-1870/T-1882/
T-1883) at pre-push time.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [completed-task-scan](/docs/generated/agents-audit-completed-task-scan) | calls | Single-pass scan of completed task files that checks for missing episodic summaries, missing research artifacts, and unchecked acceptance criteria |
| [completed-task-scan](/docs/generated/agents-audit-completed-task-scan) | tests | Single-pass scan of completed task files that checks for missing episodic summaries, missing research artifacts, and unchecked acceptance criteria |

---
*Auto-generated from Component Fabric. Card: `tests-unit-audit_ctl012_missing_decide_grandfather.yaml`*
*Last verified: 2026-08-12*
