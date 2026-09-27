# embeddings

> Embeddings blueprint — the recall substrate's own instrument panel (T-1719 A4).

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/embeddings.py`

## What It Does

How many trailing entries each ledger contributes. These are display caps, not
analysis windows — the rates above them are computed over the full window.

## Dependencies (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [embeddings](/docs/generated/web-embeddings) | calls | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [recall_telemetry](/docs/generated/web-recall_telemetry) | calls | Append-only recall telemetry — the "Used" signal (T-3019, T-3005 slice 6a). |
| [embeddings](/docs/generated/web-templates-embeddings) | renders | Embeddings panel — T-1719 A4. Tri-state rendering is load-bearing: a None value MUST read as "unknown", never as a dash or a zero. A five-month-old index passing for current (T-3004) is the failure this whole surface exists to make visible. |
| [index-health](/docs/generated/lib-index-health) | calls | Vector-index freshness verdict — T-3013 (T-3005 slice 4). |
| [shared](/docs/generated/web-shared) | uses | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [embeddings](/docs/generated/web-embeddings) | uses | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [recall_telemetry](/docs/generated/web-recall_telemetry) | uses | Append-only recall telemetry — the "Used" signal (T-3019, T-3005 slice 6a). |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | uses_by | Flask blueprint:   Init |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-embeddings.yaml`*
*Last verified: 2026-08-16*
