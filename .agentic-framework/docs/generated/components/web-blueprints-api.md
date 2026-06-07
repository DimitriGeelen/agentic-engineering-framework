# api

> Watchtower API blueprint: JSON endpoints for AJAX/htmx — task data, metrics, approval actions.

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/api.py`

## What It Does

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | imports | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [embeddings](/docs/generated/web-embeddings) | calls | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [search](/docs/generated/web-search) | calls | Tantivy BM25 full-text search engine — indexes all YAML/Markdown files, provides ranked search with snippets |

## Used By (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [test_api_ask_stream](/docs/generated/tests-playwright-test_api_ask_stream) | called_by | Playwright tests for /ask/stream SSE endpoint (T-1041). |
| [test_api_index](/docs/generated/tests-playwright-test_api_index) | called_by | Playwright tests for /api/v1 index endpoint (T-1034). |
| [test_api_search](/docs/generated/tests-playwright-test_api_search) | called_by | Playwright tests for /api/v1/search endpoint (T-1034). |
| [test_ask](/docs/generated/tests-playwright-test_ask) | called_by | Playwright tests for /api/v1/ask endpoint (T-1025). |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-api.yaml`*
*Last verified: 2026-03-09*
