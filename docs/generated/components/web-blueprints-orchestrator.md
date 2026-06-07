# orchestrator

> TODO: describe what this component does

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/orchestrator.py`

## What It Does

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [orchestrator](/docs/generated/web-templates-orchestrator) | renders | TODO: describe what this component does |
| [termlink](/docs/generated/agents-termlink-termlink) | calls | TermLink integration wrapper: spawn, exec, dispatch, cleanup, status. Adds task-tagging and budget checks around the termlink binary. |

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [test_termlink_list_contract](/docs/generated/tests-unit-test_termlink_list_contract) | called_by | TODO: describe what this component does |
| [test_orchestrator_workflow_coverage](/docs/generated/tests-unit-test_orchestrator_workflow_coverage) | called_by | TODO: describe what this component does |
| [test_orchestrator_workflow_coverage](/docs/generated/tests-unit-test_orchestrator_workflow_coverage) | registered_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-orchestrator.yaml`*
*Last verified: 2026-05-01*
