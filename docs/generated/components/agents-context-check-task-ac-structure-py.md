# check-task-ac-structure

> T-2420: Task AC structure validation hook (implements T-2418 GO).

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-task-ac-structure.py`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-inception-decisions](/docs/generated/agents-context-check-inception-decisions-py) | calls | T-1984: inception_decisions task-frontmatter validation hook. |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-task-ac-structure](/docs/generated/agents-context-check-task-ac-structure) | called_by | PreToolUse hook entry point — validates that ### Human subsection sits inside ## Acceptance Criteria block (T-2420). Bash wrapper execs check-task-ac-structure.py with the same argv (sibling parity with check-arc-id.sh / check-heredoc-cmd-sub.sh). |
| [check_task_ac_structure](/docs/generated/tests-unit-check_task_ac_structure) | tests_by | T-2420: check-task-ac-structure PreToolUse hook — unit tests. |

---
*Auto-generated from Component Fabric. Card: `agents-context-check-task-ac-structure-py.yaml`*
*Last verified: 2026-09-03*
