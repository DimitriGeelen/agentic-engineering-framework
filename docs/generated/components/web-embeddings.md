# embeddings

> sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search

**Type:** script | **Subsystem:** watchtower | **Location:** `web/embeddings.py`

**Tags:** `search`, `embeddings`, `semantic`

## What It Does

## Dependencies (18)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [search_utils](/docs/generated/web-search_utils) | calls | Watchtower search utilities: full-text search across tasks, learnings, decisions for the search page. |
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [search](/docs/generated/web-search) | calls | Tantivy BM25 full-text search engine — indexes all YAML/Markdown files, provides ranked search with snippets |
| [canary](/docs/generated/web-canary) | calls | Synthetic canary documents — a positive control for the whole retrieval path. |
| [corpus_manifest](/docs/generated/web-corpus_manifest) | calls | What the index actually contains, recorded at build time. |
| [embed_health](/docs/generated/web-embed_health) | calls | Typed liveness classification for the embedding provider (T-3006, slice 1 of T-3005). |
| [recall_telemetry](/docs/generated/web-recall_telemetry) | calls | Append-only recall telemetry — the "Used" signal (T-3019, T-3005 slice 6a). |
| [measure_chunk_tokens](/docs/generated/tools-measure_chunk_tokens) | calls | Measure the embedder's real input ceiling and the corpus chunk-token distribution. |
| [canary](/docs/generated/web-canary) | uses | Synthetic canary documents — a positive control for the whole retrieval path. |
| [corpus_manifest](/docs/generated/web-corpus_manifest) | uses | What the index actually contains, recorded at build time. |
| [embed_health](/docs/generated/web-embed_health) | uses | Typed liveness classification for the embedding provider (T-3006, slice 1 of T-3005). |
| [search_utils](/docs/generated/web-search_utils) | uses | Watchtower search utilities: full-text search across tasks, learnings, decisions for the search page. |
| [shared](/docs/generated/web-shared) | uses | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [search](/docs/generated/web-search) | uses | Tantivy BM25 full-text search engine — indexes all YAML/Markdown files, provides ranked search with snippets |
| [config](/docs/generated/web-config) | calls | Environment-based configuration for Watchtower. |
| [config](/docs/generated/web-config) | uses | Environment-based configuration for Watchtower. |

## Used By (28)

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
| [test_recall_miss_live](/docs/generated/tests-integration-test_recall_miss_live) | called_by | Live-retriever integration pin for the T-3021 miss classifier. |
| [t1719_post_write_index](/docs/generated/tests-unit-t1719_post_write_index) | tests_by | T-1719 A1 — the post-write index hook, and the boundary of where it may be wired. |
| [t3058_reindex_scratch_ignored](/docs/generated/tests-unit-t3058_reindex_scratch_ignored) | tests_by | T-3058 — the vector reindex scratch copy must be gitignored. |
| [test_canary_manifest](/docs/generated/tests-unit-test_canary_manifest) | called_by | Canary + corpus manifest — T-3011 (slice 2 of T-3005). |
| [test_chunk_cap](/docs/generated/tests-unit-test_chunk_cap) | called_by | The chunker must never emit a chunk the embedder cannot swallow whole. |
| [test_embed_health](/docs/generated/tests-unit-test_embed_health) | called_by | T-3006: the embed-path liveness classifier and the bounded retry. |
| [test_incremental_reindex](/docs/generated/tests-unit-test_incremental_reindex) | called_by | Incremental reindex — T-3014, slice 5 of T-3005. |
| [test_index_freshness](/docs/generated/tests-unit-test_index_freshness) | called_by | Index freshness is a property of the index, not of the handle — T-3012. |
| [measure_chunk_tokens](/docs/generated/tools-measure_chunk_tokens) | called_by | Measure the embedder's real input ceiling and the corpus chunk-token distribution. |
| [probe_handover_recall](/docs/generated/tools-probe_handover_recall) | called_by | Probe: when the index is queried, which handovers come back, and how old are they? |
| [app](/docs/generated/web-app) | uses_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [api](/docs/generated/web-blueprints-api) | uses_by | Watchtower API blueprint: JSON endpoints for AJAX/htmx — task data, metrics, approval actions. |
| [discovery_blueprint](/docs/generated/web-blueprints-discovery) | uses_by | Watchtower discovery page — decisions, learnings, gaps, search, graduation |
| [embeddings](/docs/generated/web-blueprints-embeddings) | called_by | Embeddings blueprint — the recall substrate's own instrument panel (T-1719 A4). |
| [embeddings](/docs/generated/web-blueprints-embeddings) | uses_by | Embeddings blueprint — the recall substrate's own instrument panel (T-1719 A4). |
| [recall_telemetry](/docs/generated/web-recall_telemetry) | called_by | Append-only recall telemetry — the "Used" signal (T-3019, T-3005 slice 6a). |
| [memory-recall](/docs/generated/agents-context-lib-memory-recall) | called_by | Memory recall — query project knowledge for relevant prior learnings, patterns, and decisions. |
| [memory-recall](/docs/generated/agents-context-lib-memory-recall) | uses_by | Memory recall — query project knowledge for relevant prior learnings, patterns, and decisions. |

---
*Auto-generated from Component Fabric. Card: `web-embeddings.yaml`*
*Last verified: 2026-02-22*
