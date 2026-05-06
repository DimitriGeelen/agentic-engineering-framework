# api

> Watchtower API blueprint: JSON endpoints for AJAX/htmx — task data, metrics, approval actions.

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/api.py`

## What It Does

## Dependencies (4)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | imports |
| `web/shared.py` | calls |
| `web/embeddings.py` | calls |
| `web/search.py` | calls |

## Used By (8)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/__init__.py` | called_by |
| `web/blueprints/__init__.py` | registered_by |
| `tests/playwright/test_api_ask_stream.py` | called_by |
| `tests/playwright/test_api_index.py` | called_by |
| `tests/playwright/test_api_search.py` | called_by |
| `tests/playwright/test_ask.py` | called_by |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-api.yaml`*
*Last verified: 2026-03-09*
