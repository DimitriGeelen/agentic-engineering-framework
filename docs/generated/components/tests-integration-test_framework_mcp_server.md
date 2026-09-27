# test_framework_mcp_server

> T-2265 (arc-010 Slice 2): integration tests for framework MCP server.

**Type:** script | **Subsystem:** tests | **Location:** `tests/integration/test_framework_mcp_server.bats`

## What It Does

T-2265 (arc-010 Slice 2): integration tests for framework MCP server.
Surfaces under test:
- agents/mcp/manifest.py       — emit manifest from tool-set.yaml
- agents/mcp/framework_mcp_server.py — stdio MCP server
- bin/fw mcp emit-manifest|status|start|stop — CLI lifecycle
- agents/audit/orchestrator-mcp-scan.sh probe_framework_tools() — drift scan
AC mapping (per .tasks/active/T-2265-*.md):
manifest emitted from tool-set.yaml          — t1
manifest contract (name+gated only)          — t2
16 read_only + 6 agent_authority             — t3

## Dependencies (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [orchestrator-mcp-scan](/docs/generated/agents-audit-orchestrator-mcp-scan) | calls | orchestrator-mcp-scan.sh — drift defense for MCP-tool task_id enforcement T-1646 (Arc C drift defense, parented under T-1644, originating in T-1641) |
| [manifest](/docs/generated/agents-mcp-manifest) | calls | Manifest emission for the framework MCP server (T-2265): derives framework-mcp-manifest.json from policy/capability-overlay/tool-set.yaml, emitting the {name, gated} contract consumed by orchestrator-mcp-scan. |
| [framework_mcp_server](/docs/generated/agents-mcp-framework_mcp_server) | calls | Framework MCP server (arc-010 Slice 2, T-2265): reads policy/capability-overlay/tool-set.yaml at startup, emits framework-mcp-manifest.json, and registers an MCP tool per read_only and agent_authority entry. |
| [orchestrator-mcp-scan](/docs/generated/agents-audit-orchestrator-mcp-scan) | tests | orchestrator-mcp-scan.sh — drift defense for MCP-tool task_id enforcement T-1646 (Arc C drift defense, parented under T-1644, originating in T-1641) |
| [manifest](/docs/generated/agents-mcp-manifest) | tests | Manifest emission for the framework MCP server (T-2265): derives framework-mcp-manifest.json from policy/capability-overlay/tool-set.yaml, emitting the {name, gated} contract consumed by orchestrator-mcp-scan. |
| [framework_mcp_server](/docs/generated/agents-mcp-framework_mcp_server) | tests | Framework MCP server (arc-010 Slice 2, T-2265): reads policy/capability-overlay/tool-set.yaml at startup, emits framework-mcp-manifest.json, and registers an MCP tool per read_only and agent_authority entry. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-integration-test_framework_mcp_server.yaml`*
*Last verified: 2026-06-08*
