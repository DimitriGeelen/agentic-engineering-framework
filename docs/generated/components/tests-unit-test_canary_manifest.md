# test_canary_manifest

> Canary + corpus manifest — T-3011 (slice 2 of T-3005).

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_canary_manifest.py`

## What It Does

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [search_utils](/docs/generated/web-search_utils) | calls | Watchtower search utilities: full-text search across tasks, learnings, decisions for the search page. |
| [canary](/docs/generated/web-canary) | calls | Synthetic canary documents — a positive control for the whole retrieval path. |
| [corpus_manifest](/docs/generated/web-corpus_manifest) | calls | What the index actually contains, recorded at build time. |
| [embeddings](/docs/generated/web-embeddings) | calls | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [search_utils](/docs/generated/web-search_utils) | uses | Watchtower search utilities: full-text search across tasks, learnings, decisions for the search page. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_canary_manifest.yaml`*
*Last verified: 2026-08-15*
