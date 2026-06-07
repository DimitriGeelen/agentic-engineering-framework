# audit_scan

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/audit_scan.bats`

## What It Does

Unit tests for audit scan scripts (T-961)

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [active-task-scan](/docs/generated/agents-audit-active-task-scan) | calls | Single-pass scan of active task files that checks compliance, quality, research artifacts, ownership, and review queue status in one efficient pass |
| [completed-task-scan](/docs/generated/agents-audit-completed-task-scan) | calls | Single-pass scan of completed task files that checks for missing episodic summaries, missing research artifacts, and unchecked acceptance criteria |
| [active-task-scan](/docs/generated/agents-audit-active-task-scan) | tests | Single-pass scan of active task files that checks compliance, quality, research artifacts, ownership, and review queue status in one efficient pass |
| [completed-task-scan](/docs/generated/agents-audit-completed-task-scan) | tests | Single-pass scan of completed task files that checks for missing episodic summaries, missing research artifacts, and unchecked acceptance criteria |

## Related

### Tasks
- T-961: Unit tests for audit scan scripts (active-task-scan.py, completed-task-scan.py)

---
*Auto-generated from Component Fabric. Card: `tests-unit-audit_scan.yaml`*
*Last verified: 2026-04-06*
