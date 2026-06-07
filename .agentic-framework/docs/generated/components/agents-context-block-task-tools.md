# block-task-tools

> PreToolUse hook that blocks Claude Code built-in task/todo tools to prevent bypassing framework task governance

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/block-task-tools.sh`

## What It Does

Block Claude Code built-in task/todo tools — bypasses framework governance (T-1115/T-1117)
The built-in TodoWrite/TaskCreate tools populate a parallel, ungoverned
task list. Use fw work-on to create real framework tasks instead.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [block_task_tools](/docs/generated/tests-unit-block_task_tools) | called_by | TODO: describe what this component does |
| [block_task_tools](/docs/generated/tests-unit-block_task_tools) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `agents-context-block-task-tools.yaml`*
*Last verified: 2026-04-12*
