# check-dispatch-pre

> PreToolUse hook: gate agent dispatch count — blocks Agent tool when parallel limit reached (max 5). Prevents T-073-class context explosions.

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-dispatch-pre.sh`

## What It Does

Dispatch Pre-Gate — PreToolUse hook for Task tool calls
Validates preamble inclusion before sub-agent dispatch (G-008 enforcement)
Three incidents (T-073: 177K spike, T-158, T-170) proved that unbounded
sub-agent output crashes sessions. PostToolUse advisory (check-dispatch.sh)
warns AFTER the damage. This hook prevents dispatch WITHOUT preamble.
Detection:
1. Only fires for Task tool calls (not TaskOutput)
2. Checks if prompt contains preamble markers
3. Blocks if markers are absent (exit code 2)
Exempt dispatches:

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [preamble](/docs/generated/agents-dispatch-preamble) | reads | Mandatory dispatch preamble — output rules for sub-agents to prevent context explosion (T-073). Requires disk writes, <=5 line responses. |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-agent-dispatch](/docs/generated/agents-context-check-agent-dispatch) | complements | Agent Dispatch Gate — PreToolUse hook for Agent tool. Tracks dispatches per session, blocks 3rd+ unless approved or TermLink not installed. |

---
*Auto-generated from Component Fabric. Card: `agents-context-check-dispatch-pre.yaml`*
*Last verified: 2026-03-23*
