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

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_termlink_list_contract](/docs/generated/tests-unit-test_termlink_list_contract) | called_by | TODO: describe what this component does |
| [test_orchestrator_mcp_classify](/docs/generated/tests-unit-test_orchestrator_mcp_classify) | called_by | TODO: describe what this component does |
| [test_reviewer_ac_evidence_untick](/docs/generated/tests-unit-test_reviewer_ac_evidence_untick) | called_by | TODO: describe what this component does |
| [check_termlink_tag_drift](/docs/generated/tools-check_termlink_tag_drift) | called_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `agents-audit-orchestrator-mcp-scan.yaml`*
*Last verified: 2026-05-01*
