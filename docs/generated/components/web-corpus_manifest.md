# corpus_manifest

> What the index actually contains, recorded at build time.

**Type:** script | **Subsystem:** watchtower | **Location:** `web/corpus_manifest.py`

## What It Does

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_canary_manifest](/docs/generated/tests-unit-test_canary_manifest) | called_by | Canary + corpus manifest — T-3011 (slice 2 of T-3005). |
| [test_incremental_reindex](/docs/generated/tests-unit-test_incremental_reindex) | called_by | Incremental reindex — T-3014, slice 5 of T-3005. |
| [test_index_freshness](/docs/generated/tests-unit-test_index_freshness) | called_by | Index freshness is a property of the index, not of the handle — T-3012. |
| [embeddings](/docs/generated/web-embeddings) | called_by | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [embeddings](/docs/generated/web-embeddings) | uses_by | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |

---
*Auto-generated from Component Fabric. Card: `web-corpus_manifest.yaml`*
*Last verified: 2026-08-15*
