# check_termlink_tag_drift

> Scan live TermLink sessions for non-canonical tag prefixes.

**Type:** script | **Subsystem:** framework-core | **Location:** `tools/check_termlink_tag_drift.py`

## What It Does

Mirrors agents/audit/orchestrator-mcp-scan.sh:101-104. Routing-relevant colon-
separated prefixes + host metadata equals-separated prefixes are all canonical.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [orchestrator-mcp-scan](/docs/generated/agents-audit-orchestrator-mcp-scan) | calls | orchestrator-mcp-scan.sh — drift defense for MCP-tool task_id enforcement T-1646 (Arc C drift defense, parented under T-1644, originating in T-1641) |

---
*Auto-generated from Component Fabric. Card: `tools-check_termlink_tag_drift.yaml`*
*Last verified: 2026-05-31*
