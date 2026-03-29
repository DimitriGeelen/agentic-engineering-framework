# learnings-route

> Serve the /learnings page showing all project learnings, patterns, and practices.

**Type:** route | **Subsystem:** learnings-pipeline | **Location:** `web/blueprints/discovery.py`

**Tags:** `learning`, `web`, `watchtower`, `discovery`

## What It Does

## Dependencies (14)

| Target | Relationship |
|--------|-------------|
| `F-001` | reads |
| `F-002` | reads |
| `C-006` | renders |
| `web/shared.py` | calls |
| `web/templates/decisions.html` | renders |
| `web/templates/gaps.html` | renders |
| `web/templates/search.html` | renders |
| `web/templates/patterns.html` | renders |
| `web/templates/graduation.html` | renders |
| `web/context_loader.py` | calls |
| `web/embeddings.py` | calls |
| `web/search.py` | calls |
| `web/search_utils.py` | calls |
| `web/templates/feedback_analytics.html` | renders |

## Used By (6)

| Component | Relationship |
|-----------|-------------|
| `C-006` | htmx |
| `web/app.py` | called_by |
| `web/app.py` | registered_by |
| `C-006` | rendered_by |
| `web/blueprints/__init__.py` | called_by |
| `web/blueprints/__init__.py` | registered_by |

---
*Auto-generated from Component Fabric. Card: `learnings-route.yaml`*
*Last verified: 2026-02-20*
