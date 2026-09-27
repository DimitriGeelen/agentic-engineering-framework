# test_recall_miss_live

> Live-retriever integration pin for the T-3021 miss classifier.

**Type:** script | **Subsystem:** tests | **Location:** `tests/integration/test_recall_miss_live.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [embeddings](/docs/generated/web-embeddings) | calls | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [recall_telemetry](/docs/generated/web-recall_telemetry) | calls | Append-only recall telemetry — the "Used" signal (T-3019, T-3005 slice 6a). |

---
*Auto-generated from Component Fabric. Card: `tests-integration-test_recall_miss_live.yaml`*
*Last verified: 2026-08-15*
