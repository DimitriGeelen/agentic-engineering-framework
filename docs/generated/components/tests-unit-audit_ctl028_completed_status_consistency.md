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

| Target | Relationship |
|--------|-------------|
| `C-004` | calls |
| `agents/audit/completed-task-scan.py` | calls |
| `agents/audit/active-task-scan.py` | calls |
| `C-004` | tests |
| `agents/audit/completed-task-scan.py` | tests |
| `agents/audit/active-task-scan.py` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-audit_ctl028_completed_status_consistency.yaml`*
*Last verified: 2026-05-15*
