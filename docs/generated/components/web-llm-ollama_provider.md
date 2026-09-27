# ollama_provider

> Ollama LLM provider — wraps the ollama Python library behind the LLMProvider interface (T-377)

**Type:** script | **Subsystem:** watchtower | **Location:** `web/llm/ollama_provider.py`

## What It Does

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [provider](/docs/generated/web-llm-provider) | calls | LLM provider abstraction — Strategy-pattern interface and shared data types (LLMProvider, ModelInfo, StreamChunk) for hot-switchable providers (T-377) |
| [ask](/docs/generated/web-ask) | calls | LLM-assisted Q&A for Watchtower search. |
| [provider](/docs/generated/web-llm-provider) | uses | LLM provider abstraction — Strategy-pattern interface and shared data types (LLMProvider, ModelInfo, StreamChunk) for hot-switchable providers (T-377) |

## Used By (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [cron](/docs/generated/web-blueprints-cron) | called_by | Watchtower cron blueprint: cron job status display — shows registered jobs, schedule, last run, active/paused state. |
| [cron](/docs/generated/web-blueprints-cron) | uses_by | Watchtower cron blueprint: cron job status display — shows registered jobs, schedule, last run, active/paused state. |
| [settings](/docs/generated/web-blueprints-settings) | called_by | Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state. |
| [settings](/docs/generated/web-blueprints-settings) | uses_by | Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state. |
| [manager](/docs/generated/web-llm-manager) | called_by | LLM provider manager — registration, active-provider selection, hot-switching and failover between Ollama and OpenRouter (T-377) |
| [manager](/docs/generated/web-llm-manager) | uses_by | LLM provider manager — registration, active-provider selection, hot-switching and failover between Ollama and OpenRouter (T-377) |

---
*Auto-generated from Component Fabric. Card: `web-llm-ollama_provider.yaml`*
*Last verified: 2026-09-08*
