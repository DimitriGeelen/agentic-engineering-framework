# orchestrator

> T-1647 (W10 #2 of T-1641 Arc C) — Watchtower /orchestrator page.

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/orchestrator.py`

## What It Does

## Dependencies (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [orchestrator](/docs/generated/web-templates-orchestrator) | renders | Orchestrator dispatch-substrate dashboard, rendered by web/blueprints/orchestrator.py. |
| [termlink](/docs/generated/agents-termlink-termlink) | calls | TermLink integration wrapper: spawn, exec, dispatch, cleanup, status. Adds task-tagging and budget checks around the termlink binary. |
| [orchestrator_parallel](/docs/generated/web-templates-orchestrator_parallel) | renders | T-2342 (arc-011 M1 §5) — visual surface for in-flight dispatches. |
| [orchestrator-mcp-scan](/docs/generated/agents-audit-orchestrator-mcp-scan) | calls | orchestrator-mcp-scan.sh — drift defense for MCP-tool task_id enforcement T-1646 (Arc C drift defense, parented under T-1644, originating in T-1641) |
| [shared](/docs/generated/web-shared) | uses | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |

## Used By (11)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [test_termlink_list_contract](/docs/generated/tests-unit-test_termlink_list_contract) | called_by | T-1651 — TermLink `list --json` schema contract test. |
| [test_orchestrator_workflow_coverage](/docs/generated/tests-unit-test_orchestrator_workflow_coverage) | called_by | T-1799: /orchestrator surfaces Workflow coverage panel. |
| [test_orchestrator_workflow_coverage](/docs/generated/tests-unit-test_orchestrator_workflow_coverage) | registered_by | T-1799: /orchestrator surfaces Workflow coverage panel. |
| [test_orchestrator_parallel_view](/docs/generated/tests-unit-test_orchestrator_parallel_view) | called_by | T-2342 (arc-011 M1 §5) — /orchestrator/parallel view. |
| [test_orchestrator_parallel_view](/docs/generated/tests-unit-test_orchestrator_parallel_view) | registered_by | T-2342 (arc-011 M1 §5) — /orchestrator/parallel view. |
| [test_termlink_governance_frame_contract](/docs/generated/tests-unit-test_termlink_governance_frame_contract) | called_by | T-1648 — Governance frame 0x8 protocol regression test. |
| [test_orchestrator_parallel_view](/docs/generated/tests-unit-test_orchestrator_parallel_view) | uses_by | T-2342 (arc-011 M1 §5) — /orchestrator/parallel view. |
| [test_orchestrator_workflow_coverage](/docs/generated/tests-unit-test_orchestrator_workflow_coverage) | uses_by | T-1799: /orchestrator surfaces Workflow coverage panel. |
| [__init__](/docs/generated/web-blueprints-__init__) | uses_by | Flask blueprint:   Init |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-orchestrator.yaml`*
*Last verified: 2026-05-01*
