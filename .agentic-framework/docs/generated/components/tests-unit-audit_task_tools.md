# audit_task_tools

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/audit_task_tools.bats`

## What It Does

Unit tests for agents/context/audit-task-tools.sh (T-1118)
PostToolUse scanner that detects TodoWrite/TaskCreate usage and warns.
Exit code: always 0 (advisory). Output: JSON additionalContext when banned tool found.

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-task-tools](/docs/generated/agents-context-audit-task-tools) | calls | PostToolUse hook detecting TodoWrite/TaskCreate bypass (T-1115/T-1118). Advisory — warns agent when banned task tools are used. |
| [audit-task-tools](/docs/generated/agents-context-audit-task-tools) | tests | PostToolUse hook detecting TodoWrite/TaskCreate bypass (T-1115/T-1118). Advisory — warns agent when banned task tools are used. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-audit_task_tools.yaml`*
*Last verified: 2026-04-12*
