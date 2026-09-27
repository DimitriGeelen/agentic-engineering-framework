# openrouter_provider

> OpenRouter LLM provider — OpenAI-compatible API client behind the LLMProvider interface (T-377)

**Type:** script | **Subsystem:** watchtower | **Location:** `web/llm/openrouter_provider.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [provider](/docs/generated/web-llm-provider) | calls | LLM provider abstraction — Strategy-pattern interface and shared data types (LLMProvider, ModelInfo, StreamChunk) for hot-switchable providers (T-377) |
| [provider](/docs/generated/web-llm-provider) | uses | LLM provider abstraction — Strategy-pattern interface and shared data types (LLMProvider, ModelInfo, StreamChunk) for hot-switchable providers (T-377) |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [settings](/docs/generated/web-blueprints-settings) | called_by | Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state. |
| [settings](/docs/generated/web-blueprints-settings) | uses_by | Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state. |
| [manager](/docs/generated/web-llm-manager) | called_by | LLM provider manager — registration, active-provider selection, hot-switching and failover between Ollama and OpenRouter (T-377) |
| [manager](/docs/generated/web-llm-manager) | uses_by | LLM provider manager — registration, active-provider selection, hot-switching and failover between Ollama and OpenRouter (T-377) |

---
*Auto-generated from Component Fabric. Card: `web-llm-openrouter_provider.yaml`*
*Last verified: 2026-09-08*
