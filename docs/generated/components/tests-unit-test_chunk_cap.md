# test_chunk_cap

> The chunker must never emit a chunk the embedder cannot swallow whole.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_chunk_cap.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [embeddings](/docs/generated/web-embeddings) | calls | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [measure_chunk_tokens](/docs/generated/tools-measure_chunk_tokens) | calls | Measure the embedder's real input ceiling and the corpus chunk-token distribution. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_chunk_cap.yaml`*
*Last verified: 2026-08-15*
