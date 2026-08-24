# search_utils

> Watchtower search utilities: full-text search across tasks, learnings, decisions for the search page.

**Type:** script | **Subsystem:** watchtower | **Location:** `web/search_utils.py`

## What It Does

## Dependencies (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | imports | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [search](/docs/generated/web-search) | calls | Tantivy BM25 full-text search engine — indexes all YAML/Markdown files, provides ranked search with snippets |
| [embeddings](/docs/generated/web-embeddings) | calls | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |
| [shared](/docs/generated/web-shared) | uses | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |

## Used By (17)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [learnings-route](/docs/generated/learnings-route) | called_by | Serve the /learnings page showing all project learnings, patterns, and practices. |
| [app](/docs/generated/web-app) | called_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [embeddings](/docs/generated/web-embeddings) | called_by | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [search](/docs/generated/web-search) | called_by | Tantivy BM25 full-text search engine — indexes all YAML/Markdown files, provides ranked search with snippets |
| [discovery_blueprint](/docs/generated/web-blueprints-discovery) | called_by | Watchtower discovery page — decisions, learnings, gaps, search, graduation |
| [shared](/docs/generated/web-shared) | called_by | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [learnings-route](/docs/generated/learnings-route) | uses_by | Serve the /learnings page showing all project learnings, patterns, and practices. |
| [test_canary_manifest](/docs/generated/tests-unit-test_canary_manifest) | called_by | TODO: describe what this component does |
| [test_canary_manifest](/docs/generated/tests-unit-test_canary_manifest) | uses_by | TODO: describe what this component does |
| [test_incremental_reindex](/docs/generated/tests-unit-test_incremental_reindex) | called_by | TODO: describe what this component does |
| [measure_corpus_classes](/docs/generated/tools-measure_corpus_classes) | called_by | TODO: describe what this component does |
| [measure_corpus_classes](/docs/generated/tools-measure_corpus_classes) | uses_by | TODO: describe what this component does |
| [app](/docs/generated/web-app) | uses_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [config](/docs/generated/web-blueprints-config) | called_by | Flask blueprint that renders the configuration settings page showing all framework settings with current values and resolution sources |
| [discovery_blueprint](/docs/generated/web-blueprints-discovery) | uses_by | Watchtower discovery page — decisions, learnings, gaps, search, graduation |
| [embeddings](/docs/generated/web-embeddings) | uses_by | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [search](/docs/generated/web-search) | uses_by | Tantivy BM25 full-text search engine — indexes all YAML/Markdown files, provides ranked search with snippets |

---
*Auto-generated from Component Fabric. Card: `web-search_utils.yaml`*
*Last verified: 2026-03-09*
