# chat

> Ask AI chat tab JavaScript — streaming SSE client, conversation state management, save/load conversations, provider/model switching

**Type:** script | **Subsystem:** watchtower | **Location:** `web/static/js/chat.js`

**Tags:** `chat`, `rag`, `llm`, `streaming`

## What It Does

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [utils](/docs/generated/web-static-js-utils) | calls | Shared JS utilities — StreamFetcher for SSE streaming, showToast for notifications, CSRF helpers |
| [markdown-render](/docs/generated/web-static-js-markdown-render) | calls | Markdown rendering utility — converts markdown text to safe HTML using marked.js and DOMPurify |
| [discovery_blueprint](/docs/generated/web-blueprints-discovery) | calls | Watchtower discovery page — decisions, learnings, gaps, search, graduation |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [chat_tab](/docs/generated/web-templates-_partials-chat_tab) | renders | Ask AI chat tab HTML partial — message thread, input bar, model/provider selector, scope filter, saved conversations sidebar |
| [chat_tab](/docs/generated/web-templates-_partials-chat_tab) | rendered_by | Ask AI chat tab HTML partial — message thread, input bar, model/provider selector, scope filter, saved conversations sidebar |

---
*Auto-generated from Component Fabric. Card: `web-static-js-chat.yaml`*
*Last verified: 2026-03-10*
