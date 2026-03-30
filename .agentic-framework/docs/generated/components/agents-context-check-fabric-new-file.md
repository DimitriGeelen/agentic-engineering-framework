# check-fabric-new-file

> TODO: describe what this component does

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-fabric-new-file.sh`

## What It Does

Fabric Registration Reminder — PostToolUse hook for Write tool
When a NEW source file is created matching watch-patterns.yaml globs,
emits an advisory reminder to register it in the Component Fabric.
Exit code: always 0 (advisory only, never blocks)
Output: JSON with additionalContext when reminder needed
Part of: Agentic Engineering Framework (T-371)

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `agents/fabric/fabric.sh` | calls |

---
*Auto-generated from Component Fabric. Card: `agents-context-check-fabric-new-file.yaml`*
*Last verified: 2026-03-09*
