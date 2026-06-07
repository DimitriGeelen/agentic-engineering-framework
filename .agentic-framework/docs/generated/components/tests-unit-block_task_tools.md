# block_task_tools

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/block_task_tools.bats`

## What It Does

Unit tests for agents/context/block-task-tools.sh (T-1117)
PreToolUse hook that blocks TodoWrite/TaskCreate/TaskUpdate/TaskList/TaskGet.
Exit code: always 2 (block). Redirects to bin/fw work-on.

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [block-task-tools](/docs/generated/agents-context-block-task-tools) | calls | PreToolUse hook that blocks Claude Code built-in task/todo tools to prevent bypassing framework task governance |
| [block-task-tools](/docs/generated/agents-context-block-task-tools) | tests | PreToolUse hook that blocks Claude Code built-in task/todo tools to prevent bypassing framework task governance |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-block_task_tools.yaml`*
*Last verified: 2026-04-12*
