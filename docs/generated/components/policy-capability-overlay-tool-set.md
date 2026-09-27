# capability-overlay-tool-set

> Framework MCP tool catalogue (arc-010): source of truth for the capability overlay from which agents/mcp/manifest.py emits framework-mcp-manifest.json. Content drift vs the emitted manifest is gated by fw doctor and the T-2290 verification rule.

**Type:** config | **Subsystem:** governance | **Location:** `policy/capability-overlay/tool-set.yaml`

**Tags:** `policy`, `mcp`, `arc-010`, `capability-overlay`

## What It Does

policy/capability-overlay/tool-set.yaml
Canonical tool-set classification for arc-010 (capability-overlay).
Sourced from docs/reports/T-2209-cli-mcp-overlay-inception.md §3.
Filed under T-2258 (arc-010 Slice 1A).
Three classes:
read_only                   — passive verbs; safe to expose unconditionally.
No state change, no authority required.
agent_authority             — state-changing verbs an agent may invoke under
framework governance (task_id required, gates
enforce focus/active-task/budget). Expose with

## Used By (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [manifest](/docs/generated/agents-mcp-manifest) | reads | Manifest emission for the framework MCP server (T-2265): derives framework-mcp-manifest.json from policy/capability-overlay/tool-set.yaml, emitting the {name, gated} contract consumed by orchestrator-mcp-scan. |
| [framework_mcp_server](/docs/generated/agents-mcp-framework_mcp_server) | reads | Framework MCP server (arc-010 Slice 2, T-2265): reads policy/capability-overlay/tool-set.yaml at startup, emits framework-mcp-manifest.json, and registers an MCP tool per read_only and agent_authority entry. |
| [govd_policy](/docs/generated/lib-govd_policy) | reads | govd_policy — proxy-policy emit / install / drift (arc-013 / T-2432, design §4c). |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | reads | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| `agents/mcp/framework-mcp-manifest.json` | triggers | — |
| [upgrade](/docs/generated/lib-upgrade) | writes | fw upgrade - Sync framework improvements to a consumer project |

---
*Auto-generated from Component Fabric. Card: `policy-capability-overlay-tool-set.yaml`*
*Last verified: 2026-09-08*
