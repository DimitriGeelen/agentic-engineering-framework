# test_embed_health

> T-3006: the embed-path liveness classifier and the bounded retry.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_embed_health.py`

## What It Does

classify() — one class per failure shape

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [embed_health](/docs/generated/web-embed_health) | calls | Typed liveness classification for the embedding provider (T-3006, slice 1 of T-3005). |
| [embeddings](/docs/generated/web-embeddings) | calls | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [config](/docs/generated/web-config) | calls | Environment-based configuration for Watchtower. |
| [config](/docs/generated/web-config) | uses | Environment-based configuration for Watchtower. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_embed_health.yaml`*
*Last verified: 2026-08-15*
