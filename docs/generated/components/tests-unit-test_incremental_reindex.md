# test_incremental_reindex

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_incremental_reindex.py`

## What It Does

Captured before any fixture runs, because the `project` fixture replaces
E._embed with a fake. The host-routing test needs the real one — routing is

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [corpus_manifest](/docs/generated/web-corpus_manifest) | calls | TODO: describe what this component does |
| [embeddings](/docs/generated/web-embeddings) | calls | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [search_utils](/docs/generated/web-search_utils) | calls | Watchtower search utilities: full-text search across tasks, learnings, decisions for the search page. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_incremental_reindex.yaml`*
*Last verified: 2026-08-15*
