# search

> Tantivy BM25 full-text search engine — indexes all YAML/Markdown files, provides ranked search with snippets

**Type:** script | **Subsystem:** watchtower | **Location:** `web/search.py`

**Tags:** `search`, `bm25`, `tantivy`

## What It Does

Index lives in /tmp — ephemeral, rebuilt as needed

## Dependencies (4)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | imports |
| `web/blueprints/discovery.py` | imported_by |
| `web/search_utils.py` | calls |
| `web/shared.py` | calls |

## Used By (4)

| Component | Relationship |
|-----------|-------------|
| `C-003` | called_by |
| `web/blueprints/api.py` | called_by |
| `web/embeddings.py` | called_by |
| `web/blueprints/discovery.py` | called_by |

---
*Auto-generated from Component Fabric. Card: `web-search.yaml`*
*Last verified: 2026-02-21*
