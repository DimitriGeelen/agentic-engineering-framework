# audit-task-tools

> TODO: describe what this component does

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/audit-task-tools.sh`

## What It Does

PostToolUse scanner: detect TodoWrite/TaskCreate usage (T-1115/T-1118)
Belt-and-braces detector. Even with PreToolUse block (T-1117), sub-agents
can bypass hooks (issue 45427 FM1). This scanner catches any successful
TodoWrite/TaskCreate call and warns the agent via additionalContext.
Exit code: always 0 (PostToolUse hooks are advisory, cannot block)
Output: JSON with additionalContext when banned tool detected, empty otherwise

---
*Auto-generated from Component Fabric. Card: `agents-context-audit-task-tools.yaml`*
*Last verified: 2026-04-12*
