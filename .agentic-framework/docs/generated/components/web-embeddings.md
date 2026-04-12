# embeddings

> sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search

**Type:** script | **Subsystem:** watchtower | **Location:** `web/embeddings.py`

**Tags:** `search`, `embeddings`, `semantic`

## What It Does

Configuration (T-273: config-driven, no hardcoded paths)

## Dependencies (5)

| Target | Relationship |
|--------|-------------|
| `web/search_utils.py` | calls |
| `web/shared.py` | calls |
| `web/search.py` | calls |

## Used By (4)

| Component | Relationship |
|-----------|-------------|
| `C-003` | called_by |
| `web/app.py` | called_by |
| `web/blueprints/api.py` | called_by |
| `web/blueprints/discovery.py` | called_by |

---
*Auto-generated from Component Fabric. Card: `web-embeddings.yaml`*
*Last verified: 2026-02-22*
