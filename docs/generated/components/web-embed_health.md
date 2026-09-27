# embed_health

> Typed liveness classification for the embedding provider (T-3006, slice 1 of T-3005).

**Type:** script | **Subsystem:** watchtower | **Location:** `web/embed_health.py`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [focus](/docs/generated/agents-context-lib-focus) | calls | Context Agent - focus command |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_embed_health](/docs/generated/tests-unit-test_embed_health) | called_by | T-3006: the embed-path liveness classifier and the bounded retry. |
| [embeddings](/docs/generated/web-embeddings) | called_by | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [embeddings](/docs/generated/web-embeddings) | uses_by | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |

---
*Auto-generated from Component Fabric. Card: `web-embed_health.yaml`*
*Last verified: 2026-08-15*
