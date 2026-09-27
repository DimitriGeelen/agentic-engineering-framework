# config

> Environment-based configuration for Watchtower.

**Type:** script | **Subsystem:** watchtower | **Location:** `web/config.py`

## What It Does

Resolve PROJECT_ROOT once (same logic as shared.py)

### Framework Reference

4-tier resolution: explicit CLI flag > `FW_*` env var > `.framework.yaml` > hardcoded default. Persistent per-project config: `fw config set KEY VALUE` writes to `.framework.yaml`.

Agent-relevant settings:
- `FW_CONTEXT_WINDOW` (300000) — budget enforcement ceiling
- `FW_PORT` (3000) — Watchtower listen port (also resolved via triple-file; see Watchtower Port section)
- `FW_SAFE_MODE` (0) — bypass task gate (escape hatch). **Must be set on the Claude
  process itself, not as a command prefix (T-3179).** `check-active-task.sh` reads the
  hook process's environment, never the command string, s

*(truncated — see CLAUDE.md for full section)*

## Used By (21)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [t3045_embed_host_resolution](/docs/generated/tests-unit-t3045_embed_host_resolution) | tests_by | T-3045 A6 — how Config.EMBED_HOST resolves, pinned. |
| [test_embed_health](/docs/generated/tests-unit-test_embed_health) | called_by | T-3006: the embed-path liveness classifier and the bounded retry. |
| [test_embed_health](/docs/generated/tests-unit-test_embed_health) | uses_by | T-3006: the embed-path liveness classifier and the bounded retry. |
| [test_incremental_reindex](/docs/generated/tests-unit-test_incremental_reindex) | called_by | Incremental reindex — T-3014, slice 5 of T-3005. |
| [test_incremental_reindex](/docs/generated/tests-unit-test_incremental_reindex) | uses_by | Incremental reindex — T-3014, slice 5 of T-3005. |
| [measure_chunk_tokens](/docs/generated/tools-measure_chunk_tokens) | called_by | Measure the embedder's real input ceiling and the corpus chunk-token distribution. |
| [measure_chunk_tokens](/docs/generated/tools-measure_chunk_tokens) | uses_by | Measure the embedder's real input ceiling and the corpus chunk-token distribution. |
| [app](/docs/generated/web-app) | called_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [app](/docs/generated/web-app) | uses_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [ask](/docs/generated/web-ask) | called_by | LLM-assisted Q&A for Watchtower search. |
| [ask](/docs/generated/web-ask) | uses_by | LLM-assisted Q&A for Watchtower search. |
| [cron](/docs/generated/web-blueprints-cron) | called_by | Watchtower cron blueprint: cron job status display — shows registered jobs, schedule, last run, active/paused state. |
| [cron](/docs/generated/web-blueprints-cron) | uses_by | Watchtower cron blueprint: cron job status display — shows registered jobs, schedule, last run, active/paused state. |
| [settings](/docs/generated/web-blueprints-settings) | called_by | Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state. |
| [settings](/docs/generated/web-blueprints-settings) | uses_by | Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state. |
| [embeddings](/docs/generated/web-embeddings) | called_by | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [embeddings](/docs/generated/web-embeddings) | uses_by | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [recall_telemetry](/docs/generated/web-recall_telemetry) | called_by | Append-only recall telemetry — the "Used" signal (T-3019, T-3005 slice 6a). |
| [recall_telemetry](/docs/generated/web-recall_telemetry) | uses_by | Append-only recall telemetry — the "Used" signal (T-3019, T-3005 slice 6a). |
| [manager](/docs/generated/web-llm-manager) | called_by | LLM provider manager — registration, active-provider selection, hot-switching and failover between Ollama and OpenRouter (T-377) |
| [manager](/docs/generated/web-llm-manager) | uses_by | LLM provider manager — registration, active-provider selection, hot-switching and failover between Ollama and OpenRouter (T-377) |

---
*Auto-generated from Component Fabric. Card: `web-config.yaml`*
*Last verified: 2026-09-03*
