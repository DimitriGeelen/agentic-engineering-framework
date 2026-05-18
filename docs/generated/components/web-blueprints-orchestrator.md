# orchestrator

> TODO: describe what this component does

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/orchestrator.py`

## What It Does

## Dependencies (3)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | calls |
| `web/templates/orchestrator.html` | renders |
| `agents/termlink/termlink.sh` | calls |

## Used By (5)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/__init__.py` | called_by |
| `web/blueprints/__init__.py` | registered_by |
| `tests/unit/test_termlink_list_contract.py` | called_by |
| `tests/unit/test_orchestrator_workflow_coverage.py` | called_by |
| `tests/unit/test_orchestrator_workflow_coverage.py` | registered_by |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-orchestrator.yaml`*
*Last verified: 2026-05-01*
