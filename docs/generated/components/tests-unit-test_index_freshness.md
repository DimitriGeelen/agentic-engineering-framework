# test_index_freshness

> Index freshness is a property of the index, not of the handle — T-3012.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_index_freshness.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [corpus_manifest](/docs/generated/web-corpus_manifest) | calls | What the index actually contains, recorded at build time. |
| [embeddings](/docs/generated/web-embeddings) | calls | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_index_freshness.yaml`*
*Last verified: 2026-08-15*
