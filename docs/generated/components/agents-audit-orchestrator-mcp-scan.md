# orchestrator-mcp-scan

> orchestrator-mcp-scan.sh — drift defense for MCP-tool task_id enforcement T-1646 (Arc C drift defense, parented under T-1644, originating in T-1641)

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

## Used By (11)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_termlink_list_contract](/docs/generated/tests-unit-test_termlink_list_contract) | called_by | T-1651 — TermLink `list --json` schema contract test. |
| [test_orchestrator_mcp_classify](/docs/generated/tests-unit-test_orchestrator_mcp_classify) | called_by | T-2154 (T-1761 build): pin classify_by_convention behaviour. |
| [test_reviewer_ac_evidence_untick](/docs/generated/tests-unit-test_reviewer_ac_evidence_untick) | called_by | T-2155 (T-1761 prevention): tests for detect_ac_evidence_untick. |
| [check_termlink_tag_drift](/docs/generated/tools-check_termlink_tag_drift) | called_by | Scan live TermLink sessions for non-canonical tag prefixes. |
| [manifest](/docs/generated/agents-mcp-manifest) | called_by | Manifest emission for the framework MCP server (T-2265): derives framework-mcp-manifest.json from policy/capability-overlay/tool-set.yaml, emitting the {name, gated} contract consumed by orchestrator-mcp-scan. |
| [test_framework_mcp_server](/docs/generated/tests-integration-test_framework_mcp_server) | called_by | T-2265 (arc-010 Slice 2): integration tests for framework MCP server. |
| [test_framework_mcp_server](/docs/generated/tests-integration-test_framework_mcp_server) | tests_by | T-2265 (arc-010 Slice 2): integration tests for framework MCP server. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [orchestrator](/docs/generated/web-blueprints-orchestrator) | called_by | T-1647 (W10 #2 of T-1641 Arc C) — Watchtower /orchestrator page. |
| [upgrade_fresh_machine_simulation](/docs/generated/tests-unit-upgrade_fresh_machine_simulation) | tests_by | T-1635: fresh-machine simulation guard for fw upgrade. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |

---
*Auto-generated from Component Fabric. Card: `agents-audit-orchestrator-mcp-scan.yaml`*
*Last verified: 2026-05-01*
