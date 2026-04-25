# core

> Flask blueprint: Core

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/core.py`

## What It Does

Active tasks with no recent update — use shared cache

### Framework Reference

**Nothing gets done without a task.** This is enforced structurally by the framework, not by agent discipline.

## Dependencies (14)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | calls |
| `web/blueprints/cockpit.py` | calls |
| `web/templates/index.html` | renders |
| `web/templates/cockpit.html` | renders |
| `web/templates/project.html` | renders |
| `web/templates/project_doc.html` | renders |
| `web/templates/directives.html` | renders |
| `web/blueprints/cockpit.py` | registers |
| `web/context_loader.py` | calls |
| `web/subprocess_utils.py` | calls |
| `web/blueprints/approvals.py` | calls |
| `web/blueprints/approvals.py` | registers |
| `web/blueprints/costs.py` | calls |
| `web/blueprints/costs.py` | registers |

## Used By (9)

| Component | Relationship |
|-----------|-------------|
| `web/app.py` | called_by |
| `web/app.py` | registered_by |
| `web/blueprints/__init__.py` | called_by |
| `web/blueprints/__init__.py` | registered_by |

## Related

### Tasks
- T-881: Upgrade consumer projects with T-879 xargs fix and T-880 init improvements

---
*Auto-generated from Component Fabric. Card: `web-blueprints-core.yaml`*
*Last verified: 2026-02-20*
