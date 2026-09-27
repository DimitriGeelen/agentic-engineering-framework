# provider

> LLM provider abstraction — Strategy-pattern interface and shared data types (LLMProvider, ModelInfo, StreamChunk) for hot-switchable providers (T-377)

**Type:** script | **Subsystem:** watchtower | **Location:** `web/llm/provider.py`

## What It Does

## Used By (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [manager](/docs/generated/web-llm-manager) | called_by | LLM provider manager — registration, active-provider selection, hot-switching and failover between Ollama and OpenRouter (T-377) |
| [manager](/docs/generated/web-llm-manager) | uses_by | LLM provider manager — registration, active-provider selection, hot-switching and failover between Ollama and OpenRouter (T-377) |
| [ollama_provider](/docs/generated/web-llm-ollama_provider) | called_by | Ollama LLM provider — wraps the ollama Python library behind the LLMProvider interface (T-377) |
| [ollama_provider](/docs/generated/web-llm-ollama_provider) | uses_by | Ollama LLM provider — wraps the ollama Python library behind the LLMProvider interface (T-377) |
| [openrouter_provider](/docs/generated/web-llm-openrouter_provider) | called_by | OpenRouter LLM provider — OpenAI-compatible API client behind the LLMProvider interface (T-377) |
| [openrouter_provider](/docs/generated/web-llm-openrouter_provider) | uses_by | OpenRouter LLM provider — OpenAI-compatible API client behind the LLMProvider interface (T-377) |

---
*Auto-generated from Component Fabric. Card: `web-llm-provider.yaml`*
*Last verified: 2026-09-08*
