# check-task-ac-structure

> PreToolUse hook entry point — validates that ### Human subsection sits inside ## Acceptance Criteria block (T-2420). Bash wrapper execs check-task-ac-structure.py with the same argv (sibling parity with check-arc-id.sh / check-heredoc-cmd-sub.sh).

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-task-ac-structure.sh`

**Tags:** `hook`, `pre-tool-use`, `task-validation`

## What It Does

T-2420: Task AC structure validation hook (bash wrapper).
The fw hook dispatcher (bin/fw) loads .sh files; actual logic in check-task-ac-structure.py.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-task-ac-structure](/docs/generated/agents-context-check-task-ac-structure-py) | calls | T-2420: Task AC structure validation hook (implements T-2418 GO). |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check_task_ac_structure](/docs/generated/tests-unit-check_task_ac_structure) | called_by | T-2420: check-task-ac-structure PreToolUse hook — unit tests. |
| [check_task_ac_structure](/docs/generated/tests-unit-check_task_ac_structure) | tests_by | T-2420: check-task-ac-structure PreToolUse hook — unit tests. |

---
*Auto-generated from Component Fabric. Card: `agents-context-check-task-ac-structure.yaml`*
*Last verified: 2026-06-16*
