# test_framework_mcp_server

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/integration/test_framework_mcp_server.bats`

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
| [orchestrator-mcp-scan](/docs/generated/agents-audit-orchestrator-mcp-scan) | calls | TODO: describe what this component does |
| [manifest](/docs/generated/agents-mcp-manifest) | calls | TODO: describe what this component does |
| [framework_mcp_server](/docs/generated/agents-mcp-framework_mcp_server) | calls | TODO: describe what this component does |
| [orchestrator-mcp-scan](/docs/generated/agents-audit-orchestrator-mcp-scan) | tests | TODO: describe what this component does |
| [manifest](/docs/generated/agents-mcp-manifest) | tests | TODO: describe what this component does |
| [framework_mcp_server](/docs/generated/agents-mcp-framework_mcp_server) | tests | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-integration-test_framework_mcp_server.yaml`*
*Last verified: 2026-06-08*
