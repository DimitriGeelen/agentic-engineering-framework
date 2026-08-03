# chat-bare-path-warn

> TODO: describe what this component does

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/chat-bare-path-warn.sh`

## What It Does

UserPromptSubmit hook — chat bare-path warner (T-2183, Slice 2 of T-2181)
Companion to chat-bare-path-scan.sh. On each UserPromptSubmit, reads any
outstanding bare-path violations recorded by the scanner, emits one agent-visible
<system-reminder> block per violation to stdout (UserPromptSubmit stdout becomes
additional context on the agent's next turn), then TRUNCATES the violations file
(consume-on-show — each violation is surfaced exactly once).
The reminder points the agent at the correct mechanism: `fw task review[-batch]`
emits class-correct full URLs (T-2182 helper); bare /review/T-XXX paths in chat
are the regression this backstop guards (T-2125 / T-2129 / T-2181).
SAFETY: non-destructive (reads + truncates one YAML file), always exits 0.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [chat-bare-path-scan](/docs/generated/agents-context-chat-bare-path-scan) | calls | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `agents-context-chat-bare-path-warn.yaml`*
*Last verified: 2026-07-22*
