# discovery_blueprint

> Watchtower discovery page — decisions, learnings, gaps, search, graduation

**Type:** blueprint | **Subsystem:** watchtower | **Location:** `web/blueprints/discovery.py`

**Tags:** `watchtower`, `flask`, `discovery`, `decisions`, `learnings`, `gaps`

## What It Does

## Dependencies (12)

| Target | Relationship |
|--------|-------------|
| `web/context_loader.py` | calls |
| `web/shared.py` | calls |
| `web/embeddings.py` | calls |
| `web/search.py` | calls |
| `web/search_utils.py` | calls |
| `web/templates/decisions.html` | renders |
| `C-006` | renders |
| `web/templates/gaps.html` | renders |
| `web/templates/search.html` | renders |
| `web/templates/feedback_analytics.html` | renders |
| `web/templates/patterns.html` | renders |
| `web/templates/graduation.html` | renders |

## Used By (6)

| Component | Relationship |
|-----------|-------------|
| `web/search.py` | used-by |
| `web/static/js/chat.js` | called-by |
| `web/blueprints/__init__.py` | called_by |
| `web/blueprints/__init__.py` | registered_by |
| `web/search.py` | imported_by_by |
| `web/static/js/chat.js` | called_by |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-discovery.yaml`*
*Last verified: 2026-04-05*
