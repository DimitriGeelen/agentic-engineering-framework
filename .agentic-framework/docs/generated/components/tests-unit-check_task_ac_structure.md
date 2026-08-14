# check_task_ac_structure

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/check_task_ac_structure.bats`

## What It Does

T-2420: check-task-ac-structure PreToolUse hook — unit tests.
Implements T-2418 GO. Hook prevents the structural error caught at the
T-2417 close cascade (S-2026-0616): `### Human` placed AFTER an intervening
`## ` heading is invisible to update-task.sh's AC parser.
Covers:
- new malformed Write under CLAUDECODE → block (exit 2)
- new correctly-structured Write → allow (exit 0)
- no-Human file → allow (no heading to check)
- override env-var FW_ALLOW_AC_STRUCTURE_DRIFT=1 → allow + log
- non-task file path → pass-through

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-task-ac-structure](/docs/generated/agents-context-check-task-ac-structure) | calls | PreToolUse hook entry point — validates that ### Human subsection sits inside ## Acceptance Criteria block (T-2420). Bash wrapper execs check-task-ac-structure.py with the same argv (sibling parity with check-arc-id.sh / check-heredoc-cmd-sub.sh). |
| [check-task-ac-structure](/docs/generated/agents-context-check-task-ac-structure) | tests | PreToolUse hook entry point — validates that ### Human subsection sits inside ## Acceptance Criteria block (T-2420). Bash wrapper execs check-task-ac-structure.py with the same argv (sibling parity with check-arc-id.sh / check-heredoc-cmd-sub.sh). |

---
*Auto-generated from Component Fabric. Card: `tests-unit-check_task_ac_structure.yaml`*
*Last verified: 2026-06-16*
