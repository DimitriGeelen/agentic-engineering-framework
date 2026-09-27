# recall_telemetry

> Append-only recall telemetry — the "Used" signal (T-3019, T-3005 slice 6a).

**Type:** script | **Subsystem:** watchtower | **Location:** `web/recall_telemetry.py`

## What It Does

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [embeddings](/docs/generated/web-embeddings) | calls | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [config](/docs/generated/web-config) | calls | Environment-based configuration for Watchtower. |
| [config](/docs/generated/web-config) | uses | Environment-based configuration for Watchtower. |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_recall_miss_live](/docs/generated/tests-integration-test_recall_miss_live) | called_by | Live-retriever integration pin for the T-3021 miss classifier. |
| [embeddings](/docs/generated/web-blueprints-embeddings) | called_by | Embeddings blueprint — the recall substrate's own instrument panel (T-1719 A4). |
| [embeddings](/docs/generated/web-blueprints-embeddings) | uses_by | Embeddings blueprint — the recall substrate's own instrument panel (T-1719 A4). |
| [embeddings](/docs/generated/web-embeddings) | called_by | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |

---
*Auto-generated from Component Fabric. Card: `web-recall_telemetry.yaml`*
*Last verified: 2026-08-15*
