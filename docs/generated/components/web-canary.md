# canary

> Synthetic canary documents — a positive control for the whole retrieval path.

**Type:** script | **Subsystem:** watchtower | **Location:** `web/canary.py`

## What It Does

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_canary_manifest](/docs/generated/tests-unit-test_canary_manifest) | called_by | Canary + corpus manifest — T-3011 (slice 2 of T-3005). |
| [embeddings](/docs/generated/web-embeddings) | called_by | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [embeddings](/docs/generated/web-embeddings) | uses_by | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |

---
*Auto-generated from Component Fabric. Card: `web-canary.yaml`*
*Last verified: 2026-08-15*
