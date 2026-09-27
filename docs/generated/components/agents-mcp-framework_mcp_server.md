# framework_mcp_server

> Framework MCP server (arc-010 Slice 2, T-2265): reads policy/capability-overlay/tool-set.yaml at startup, emits framework-mcp-manifest.json, and registers an MCP tool per read_only and agent_authority entry.

**Type:** script | **Subsystem:** framework-core | **Location:** `agents/mcp/framework_mcp_server.py`

## What It Does

T-2265 (arc-010 Slice 2): framework MCP server.
Reads policy/capability-overlay/tool-set.yaml at startup, emits the
manifest at agents/mcp/framework-mcp-manifest.json, and registers an
MCP tool for every read_only: (16) + agent_authority: (6) entry.
sovereignty_bound_excluded: (5) is NEVER registered (foreclosed today).
Transport: stdio (Claude Code default).
Backend: shell out to `bin/fw <fw_command>` to preserve existing gates.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [manifest](/docs/generated/agents-mcp-manifest) | uses | Manifest emission for the framework MCP server (T-2265): derives framework-mcp-manifest.json from policy/capability-overlay/tool-set.yaml, emitting the {name, gated} contract consumed by orchestrator-mcp-scan. |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_framework_mcp_server](/docs/generated/tests-integration-test_framework_mcp_server) | called_by | T-2265 (arc-010 Slice 2): integration tests for framework MCP server. |
| [test_framework_mcp_server](/docs/generated/tests-integration-test_framework_mcp_server) | tests_by | T-2265 (arc-010 Slice 2): integration tests for framework MCP server. |

---
*Auto-generated from Component Fabric. Card: `agents-mcp-framework_mcp_server.yaml`*
*Last verified: 2026-06-08*
