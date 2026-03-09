# core

> Flask blueprint: Core

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/core.py`

## What It Does

Active tasks with no recent update

### Framework Reference

**Nothing gets done without a task.** This is enforced structurally by the framework, not by agent discipline.

## Dependencies (8)

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

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `web/app.py` | called_by |
| `web/app.py` | registered_by |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-core.yaml`*
*Last verified: 2026-02-20*
