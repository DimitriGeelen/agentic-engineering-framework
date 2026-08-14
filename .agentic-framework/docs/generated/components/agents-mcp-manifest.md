# manifest

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `agents/mcp/manifest.py`

## What It Does

T-2265 (arc-010 Slice 2): manifest emission for the framework MCP server.
Single source of truth: policy/capability-overlay/tool-set.yaml.
Output contract (T-2260 probe_framework_tools at agents/audit/orchestrator-mcp-scan.sh:100):
{"tools": [{"name": "<verb>", "gated": <bool>}, ...]}
read_only entries  → gated: false
agent_authority    → gated: true (task_id required at MCP schema layer)
sovereignty_bound_excluded → NEVER emitted (foreclosed per tool-set.yaml §3)

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [orchestrator-mcp-scan](/docs/generated/agents-audit-orchestrator-mcp-scan) | calls | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [framework_mcp_server](/docs/generated/agents-mcp-framework_mcp_server) | uses_by | TODO: describe what this component does |
| [test_framework_mcp_server](/docs/generated/tests-integration-test_framework_mcp_server) | called_by | TODO: describe what this component does |
| [test_framework_mcp_server](/docs/generated/tests-integration-test_framework_mcp_server) | tests_by | TODO: describe what this component does |
| [hooks](/docs/generated/agents-git-lib-hooks) | called_by | Git Agent - Hook installation subcommand |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [t2461_doctor_mcp_consumer_path](/docs/generated/tests-unit-t2461_doctor_mcp_consumer_path) | tests_by | TODO: describe what this component does |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |

---
*Auto-generated from Component Fabric. Card: `agents-mcp-manifest.yaml`*
*Last verified: 2026-06-08*
