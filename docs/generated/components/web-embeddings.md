# embeddings

> sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search

**Type:** script | **Subsystem:** watchtower | **Location:** `web/embeddings.py`

**Tags:** `search`, `embeddings`, `semantic`

## What It Does

Configuration (T-273: config-driven, no hardcoded paths)

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [search_utils](/docs/generated/web-search_utils) | calls | Watchtower search utilities: full-text search across tasks, learnings, decisions for the search page. |
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [search](/docs/generated/web-search) | calls | Tantivy BM25 full-text search engine — indexes all YAML/Markdown files, provides ranked search with snippets |

## Used By (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [learnings-route](/docs/generated/learnings-route) | called_by | Serve the /learnings page showing all project learnings, patterns, and practices. |
| [app](/docs/generated/web-app) | called_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [api](/docs/generated/web-blueprints-api) | called_by | Watchtower API blueprint: JSON endpoints for AJAX/htmx — task data, metrics, approval actions. |
| [discovery_blueprint](/docs/generated/web-blueprints-discovery) | called_by | Watchtower discovery page — decisions, learnings, gaps, search, graduation |
| [search_utils](/docs/generated/web-search_utils) | called_by | Watchtower search utilities: full-text search across tasks, learnings, decisions for the search page. |
| [ask-py](/docs/generated/lib-ask-py) | called_by | Python implementation of fw ask subcommand (sibling of lib/ask.sh) |

---
*Auto-generated from Component Fabric. Card: `web-embeddings.yaml`*
*Last verified: 2026-02-22*
