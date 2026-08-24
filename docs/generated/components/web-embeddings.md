# embeddings

> sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search

**Type:** script | **Subsystem:** watchtower | **Location:** `web/embeddings.py`

**Tags:** `search`, `embeddings`, `semantic`

## What It Does

## Dependencies (16)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [search_utils](/docs/generated/web-search_utils) | calls | Watchtower search utilities: full-text search across tasks, learnings, decisions for the search page. |
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [search](/docs/generated/web-search) | calls | Tantivy BM25 full-text search engine — indexes all YAML/Markdown files, provides ranked search with snippets |
| [canary](/docs/generated/web-canary) | calls | TODO: describe what this component does |
| [corpus_manifest](/docs/generated/web-corpus_manifest) | calls | TODO: describe what this component does |
| [embed_health](/docs/generated/web-embed_health) | calls | TODO: describe what this component does |
| [recall_telemetry](/docs/generated/web-recall_telemetry) | calls | TODO: describe what this component does |
| [measure_chunk_tokens](/docs/generated/tools-measure_chunk_tokens) | calls | TODO: describe what this component does |
| [canary](/docs/generated/web-canary) | uses | TODO: describe what this component does |
| [corpus_manifest](/docs/generated/web-corpus_manifest) | uses | TODO: describe what this component does |
| [embed_health](/docs/generated/web-embed_health) | uses | TODO: describe what this component does |
| [search_utils](/docs/generated/web-search_utils) | uses | Watchtower search utilities: full-text search across tasks, learnings, decisions for the search page. |
| [shared](/docs/generated/web-shared) | uses | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [search](/docs/generated/web-search) | uses | Tantivy BM25 full-text search engine — indexes all YAML/Markdown files, provides ranked search with snippets |

## Used By (26)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [learnings-route](/docs/generated/learnings-route) | called_by | Serve the /learnings page showing all project learnings, patterns, and practices. |
| [app](/docs/generated/web-app) | called_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [api](/docs/generated/web-blueprints-api) | called_by | Watchtower API blueprint: JSON endpoints for AJAX/htmx — task data, metrics, approval actions. |
| [discovery_blueprint](/docs/generated/web-blueprints-discovery) | called_by | Watchtower discovery page — decisions, learnings, gaps, search, graduation |
| [search_utils](/docs/generated/web-search_utils) | called_by | Watchtower search utilities: full-text search across tasks, learnings, decisions for the search page. |
| [ask-py](/docs/generated/lib-ask-py) | called_by | Python implementation of fw ask subcommand (sibling of lib/ask.sh) |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [learnings-route](/docs/generated/learnings-route) | uses_by | Serve the /learnings page showing all project learnings, patterns, and practices. |
| [ask-py](/docs/generated/lib-ask-py) | uses_by | Python implementation of fw ask subcommand (sibling of lib/ask.sh) |
| [keylock-py](/docs/generated/lib-keylock-py) | called_by | Python sibling of lib/keylock.sh: sidecar fcntl.flock advisory locks in .context/locks/, with a bounded timeout that raises loudly rather than degrading to a silent skipped write. Guards the dispatch ledger against the concurrent-append erasure fixed in T-3042. |
| [test_recall_miss_live](/docs/generated/tests-integration-test_recall_miss_live) | called_by | TODO: describe what this component does |
| [t1719_post_write_index](/docs/generated/tests-unit-t1719_post_write_index) | tests_by | TODO: describe what this component does |
| [t3058_reindex_scratch_ignored](/docs/generated/tests-unit-t3058_reindex_scratch_ignored) | tests_by | TODO: describe what this component does |
| [test_canary_manifest](/docs/generated/tests-unit-test_canary_manifest) | called_by | TODO: describe what this component does |
| [test_chunk_cap](/docs/generated/tests-unit-test_chunk_cap) | called_by | TODO: describe what this component does |
| [test_embed_health](/docs/generated/tests-unit-test_embed_health) | called_by | TODO: describe what this component does |
| [test_incremental_reindex](/docs/generated/tests-unit-test_incremental_reindex) | called_by | TODO: describe what this component does |
| [test_index_freshness](/docs/generated/tests-unit-test_index_freshness) | called_by | TODO: describe what this component does |
| [measure_chunk_tokens](/docs/generated/tools-measure_chunk_tokens) | called_by | TODO: describe what this component does |
| [probe_handover_recall](/docs/generated/tools-probe_handover_recall) | called_by | TODO: describe what this component does |
| [app](/docs/generated/web-app) | uses_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [api](/docs/generated/web-blueprints-api) | uses_by | Watchtower API blueprint: JSON endpoints for AJAX/htmx — task data, metrics, approval actions. |
| [discovery_blueprint](/docs/generated/web-blueprints-discovery) | uses_by | Watchtower discovery page — decisions, learnings, gaps, search, graduation |
| [embeddings](/docs/generated/web-blueprints-embeddings) | called_by | TODO: describe what this component does |
| [embeddings](/docs/generated/web-blueprints-embeddings) | uses_by | TODO: describe what this component does |
| [recall_telemetry](/docs/generated/web-recall_telemetry) | called_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `web-embeddings.yaml`*
*Last verified: 2026-02-22*
