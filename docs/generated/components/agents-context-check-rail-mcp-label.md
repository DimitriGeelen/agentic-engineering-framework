# check-rail-mcp-label

> TODO: describe what this component does

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-rail-mcp-label.sh`

## What It Does

T-2908: PreToolUse label gate for the MCP rail-post producer surface.
T-2904/T-2905 put an identity guard and an auto-attached from_project label
inside `do_rail post` (bin/fw / lib/rail-identity.sh). The class was reported
closed. It wasn't: `mcp__termlink__termlink_channel_post` reaches the SAME
topics with neither gate in scope, because both live in OUR shell wrapper and
an MCP tool call never runs it — Claude Code calls termlink's MCP server
directly with whatever `metadata` the caller supplied.
SCOPE: this hook enforces the LABEL only, not the identity.
The label is a per-call JSON field (`tool_input.metadata.from_project`) — a
PreToolUse hook can inspect and block it, exactly like any other tool_input

---
*Auto-generated from Component Fabric. Card: `agents-context-check-rail-mcp-label.yaml`*
*Last verified: 2026-08-10*
