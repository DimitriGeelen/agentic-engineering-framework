# rail_mcp_label_guard

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/rail_mcp_label_guard.bats`

## What It Does

T-2908: the MCP producer surface (mcp__termlink__termlink_channel_post) reaches
the same rail topics as `fw rail post` with neither the T-2904 identity gate nor
the T-2905 label gate in scope, because both live inside `do_rail post` in
bin/fw and an MCP tool call never goes through that code path.
Identity is NOT re-gated here — the MCP server resolves its signing key once,
at process start, from an environment this hook cannot re-introspect per call
(T-2908 measured the split; the mechanism inside termlink is opaque and out of
our project boundary, T-559). This hook enforces the LABEL only: same
detection surface as T-2905's shell-side auto-attach, applied at the one other
call shape that reaches the topic. See CLAUDE.md L-572.

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-rail-mcp-label](/docs/generated/agents-context-check-rail-mcp-label) | calls | TODO: describe what this component does |
| [check-rail-mcp-label](/docs/generated/agents-context-check-rail-mcp-label) | tests | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-rail_mcp_label_guard.yaml`*
*Last verified: 2026-08-10*
