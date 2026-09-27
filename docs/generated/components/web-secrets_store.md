# secrets_store

> Encrypted API key storage for Watchtower.

**Type:** script | **Subsystem:** watchtower | **Location:** `web/secrets_store.py`

## What It Does

Map of key names to their environment variable overrides

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [shared](/docs/generated/web-shared) | uses | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [settings](/docs/generated/web-blueprints-settings) | called_by | Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state. |
| [settings](/docs/generated/web-blueprints-settings) | uses_by | Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state. |
| [manager](/docs/generated/web-llm-manager) | called_by | LLM provider manager — registration, active-provider selection, hot-switching and failover between Ollama and OpenRouter (T-377) |
| [manager](/docs/generated/web-llm-manager) | uses_by | LLM provider manager — registration, active-provider selection, hot-switching and failover between Ollama and OpenRouter (T-377) |

---
*Auto-generated from Component Fabric. Card: `web-secrets_store.yaml`*
*Last verified: 2026-09-03*
