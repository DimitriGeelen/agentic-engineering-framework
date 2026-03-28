# search

> Tantivy BM25 full-text search engine — indexes all YAML/Markdown files, provides ranked search with snippets

**Type:** script | **Subsystem:** watchtower | **Location:** `web/search.py`

**Tags:** `search`, `bm25`, `tantivy`

## What It Does

Index lives in /tmp — ephemeral, rebuilt as needed

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | imports |
| `web/blueprints/discovery.py` | imported_by |

## Related

### Tasks
- T-237: Add search infrastructure — tantivy BM25 for Watchtower, plan embedding layer
- T-265: Saved answers — curated Q&A for retrieval flywheel
- T-376: Python dedup: extract search_utils.py from search.py/embeddings.py

---
*Auto-generated from Component Fabric. Card: `web-search.yaml`*
*Last verified: 2026-02-21*
