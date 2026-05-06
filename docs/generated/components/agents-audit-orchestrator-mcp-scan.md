# orchestrator-mcp-scan

> TODO: describe what this component does

**Type:** script | **Subsystem:** audit | **Location:** `agents/audit/orchestrator-mcp-scan.sh`

## What It Does

orchestrator-mcp-scan.sh — drift defense for MCP-tool task_id enforcement
T-1646 (Arc C drift defense, parented under T-1644, originating in T-1641)
Detects: new MCP tools added without check_task_governance() gate; gated tools
losing their gate; mutators_ungated growing instead of shrinking.
Strategy: probe /opt/termlink via TermLink (cross-repo policy per T-559) or
direct read when running on the host that owns the repo. Inventory tools.rs
`name = "termlink_*"` entries, classify against the baseline, emit YAML summary.
Exit codes:
0  baseline match
1  drift: new unclassified tools (manual classification needed) or ratchet candidates

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `tests/unit/test_termlink_list_contract.py` | called_by |

---
*Auto-generated from Component Fabric. Card: `agents-audit-orchestrator-mcp-scan.yaml`*
*Last verified: 2026-05-01*
