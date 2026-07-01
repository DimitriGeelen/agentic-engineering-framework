# check_task_ac_structure

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/check_task_ac_structure.bats`

## What It Does

T-2420: tests for agents/context/check-task-ac-structure.{sh,py}

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-task-ac-structure](/docs/generated/agents-context-check-task-ac-structure) | calls | PreToolUse hook entry point — validates that ### Human subsection sits inside ## Acceptance Criteria block (T-2420). Bash wrapper execs check-task-ac-structure.py with the same argv (sibling parity with check-arc-id.sh / check-heredoc-cmd-sub.sh). |
| [check-task-ac-structure](/docs/generated/agents-context-check-task-ac-structure) | tests | PreToolUse hook entry point — validates that ### Human subsection sits inside ## Acceptance Criteria block (T-2420). Bash wrapper execs check-task-ac-structure.py with the same argv (sibling parity with check-arc-id.sh / check-heredoc-cmd-sub.sh). |

---
*Auto-generated from Component Fabric. Card: `tests-unit-check_task_ac_structure.yaml`*
*Last verified: 2026-06-16*
