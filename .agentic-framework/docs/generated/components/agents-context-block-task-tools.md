# block-task-tools

> PreToolUse hook that blocks Claude Code built-in task/todo tools to prevent bypassing framework task governance

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/block-task-tools.sh`

## What It Does

Block Claude Code built-in task/todo tools — bypasses framework governance (T-1115/T-1117)
The built-in TodoWrite/TaskCreate tools populate a parallel, ungoverned
task list. Use fw work-on to create real framework tasks instead.

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `lib/paths.sh` | calls |

## Used By (2)

| Component | Relationship |
|-----------|-------------|

---
*Auto-generated from Component Fabric. Card: `agents-context-block-task-tools.yaml`*
*Last verified: 2026-04-12*
