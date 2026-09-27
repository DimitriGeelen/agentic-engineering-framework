# sidecar-inbox

> sidecar-inbox.sh — UserPromptSubmit hook: surface pending peer consults.

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/sidecar-inbox.sh`

## What It Does

sidecar-inbox.sh — UserPromptSubmit hook: surface pending peer consults.
T-3407 (arc-011 slice 5). Runs `fw sidecar inbox --peek --json` and, when
consults are pending, emits them as additionalContext so the agent sees
them at the start of its next turn without having been told to look.
Three properties are load-bearing and each has a test:
PEEK, never consume — surfacing is not reading. A consult the hook
consumed and the agent then ignored would vanish from `fw sidecar
inbox`. The cursor is left where it was.
SILENT when empty — no consults means no stdout at all, so the common
case costs the turn nothing.

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [preamble](/docs/generated/agents-dispatch-preamble) | called_by | Mandatory dispatch preamble — output rules for sub-agents to prevent context explosion (T-073). Requires disk writes, <=5 line responses. |
| [hook-config](/docs/generated/hook-config) | called_by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [sidecar_inbox_hook](/docs/generated/tests-unit-sidecar_inbox_hook) | tests_by | T-3407 — sidecar-inbox UserPromptSubmit hook: silent-when-empty, surfaces when pending, peeks (never consumes), fails open. |

---
*Auto-generated from Component Fabric. Card: `agents-context-sidecar-inbox.yaml`*
*Last verified: 2026-09-21*
