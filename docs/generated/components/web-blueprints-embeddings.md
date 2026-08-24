# embeddings

> TODO: describe what this component does

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/embeddings.py`

## What It Does

How many trailing entries each ledger contributes. These are display caps, not
analysis windows — the rates above them are computed over the full window.

## Dependencies (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [embeddings](/docs/generated/web-embeddings) | calls | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [recall_telemetry](/docs/generated/web-recall_telemetry) | calls | TODO: describe what this component does |
| [embeddings](/docs/generated/web-templates-embeddings) | renders | TODO: describe what this component does |
| [index-health](/docs/generated/lib-index-health) | calls | TODO: describe what this component does |
| [shared](/docs/generated/web-shared) | uses | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [embeddings](/docs/generated/web-embeddings) | uses | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [recall_telemetry](/docs/generated/web-recall_telemetry) | uses | TODO: describe what this component does |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | uses_by | Flask blueprint:   Init |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-embeddings.yaml`*
*Last verified: 2026-08-16*
