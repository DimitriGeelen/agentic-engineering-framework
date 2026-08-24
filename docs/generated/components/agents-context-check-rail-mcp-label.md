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

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |
| [rail-identity](/docs/generated/lib-rail-identity) | calls | TODO: describe what this component does |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook-config](/docs/generated/hook-config) | called_by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [rail_mcp_label_guard](/docs/generated/tests-unit-rail_mcp_label_guard) | called_by | TODO: describe what this component does |
| [rail_mcp_label_guard](/docs/generated/tests-unit-rail_mcp_label_guard) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `agents-context-check-rail-mcp-label.yaml`*
*Last verified: 2026-08-10*
