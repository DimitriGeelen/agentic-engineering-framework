# manager

> LLM provider manager — registration, active-provider selection, hot-switching and failover between Ollama and OpenRouter (T-377)

**Type:** script | **Subsystem:** watchtower | **Location:** `web/llm/manager.py`

## What It Does

Fallback to first available

## Dependencies (12)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [provider](/docs/generated/web-llm-provider) | calls | LLM provider abstraction — Strategy-pattern interface and shared data types (LLMProvider, ModelInfo, StreamChunk) for hot-switchable providers (T-377) |
| [config](/docs/generated/web-config) | calls | Environment-based configuration for Watchtower. |
| [ollama_provider](/docs/generated/web-llm-ollama_provider) | calls | Ollama LLM provider — wraps the ollama Python library behind the LLMProvider interface (T-377) |
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [secrets_store](/docs/generated/web-secrets_store) | calls | Encrypted API key storage for Watchtower. |
| [openrouter_provider](/docs/generated/web-llm-openrouter_provider) | calls | OpenRouter LLM provider — OpenAI-compatible API client behind the LLMProvider interface (T-377) |
| [provider](/docs/generated/web-llm-provider) | uses | LLM provider abstraction — Strategy-pattern interface and shared data types (LLMProvider, ModelInfo, StreamChunk) for hot-switchable providers (T-377) |
| [config](/docs/generated/web-config) | uses | Environment-based configuration for Watchtower. |
| [ollama_provider](/docs/generated/web-llm-ollama_provider) | uses | Ollama LLM provider — wraps the ollama Python library behind the LLMProvider interface (T-377) |
| [shared](/docs/generated/web-shared) | uses | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [secrets_store](/docs/generated/web-secrets_store) | uses | Encrypted API key storage for Watchtower. |
| [openrouter_provider](/docs/generated/web-llm-openrouter_provider) | uses | OpenRouter LLM provider — OpenAI-compatible API client behind the LLMProvider interface (T-377) |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [settings](/docs/generated/web-blueprints-settings) | called_by | Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state. |
| [settings](/docs/generated/web-blueprints-settings) | uses_by | Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state. |

---
*Auto-generated from Component Fabric. Card: `web-llm-manager.yaml`*
*Last verified: 2026-09-08*
