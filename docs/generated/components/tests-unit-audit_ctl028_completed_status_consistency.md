# audit_ctl028_completed_status_consistency

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/audit_ctl028_completed_status_consistency.bats`

## What It Does

T-1870 / CTL-028: completed/ frontmatter status consistency
L-390: tasks moved to .tasks/completed/ via `git mv` (rather than
`fw task update --status work-completed`) leave frontmatter status
desynced (typically status=started-work + date_finished=null).
CTL-012 catches the AC consequence but not the bare metadata desync.
This test exercises the completed-task-scan.py directly — it's the
single source of truth for status_desync detection. The audit.sh
CTL-028 block just renders the scanner's output as WARN lines.

## Dependencies (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [completed-task-scan](/docs/generated/agents-audit-completed-task-scan) | calls | Single-pass scan of completed task files that checks for missing episodic summaries, missing research artifacts, and unchecked acceptance criteria |
| [active-task-scan](/docs/generated/agents-audit-active-task-scan) | calls | Single-pass scan of active task files that checks compliance, quality, research artifacts, ownership, and review queue status in one efficient pass |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | tests | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [completed-task-scan](/docs/generated/agents-audit-completed-task-scan) | tests | Single-pass scan of completed task files that checks for missing episodic summaries, missing research artifacts, and unchecked acceptance criteria |
| [active-task-scan](/docs/generated/agents-audit-active-task-scan) | tests | Single-pass scan of active task files that checks compliance, quality, research artifacts, ownership, and review queue status in one efficient pass |

---
*Auto-generated from Component Fabric. Card: `tests-unit-audit_ctl028_completed_status_consistency.yaml`*
*Last verified: 2026-05-15*
