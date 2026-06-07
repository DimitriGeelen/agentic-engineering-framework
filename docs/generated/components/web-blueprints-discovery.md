# discovery_blueprint

> Watchtower discovery page — decisions, learnings, gaps, search, graduation

**Type:** blueprint | **Subsystem:** watchtower | **Location:** `web/blueprints/discovery.py`

**Tags:** `watchtower`, `flask`, `discovery`, `decisions`, `learnings`, `gaps`

## What It Does

## Dependencies (14)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [context_loader](/docs/generated/web-context_loader) | calls | Centralized YAML loading for context project files (learnings, patterns, decisions, practices, concerns, directives). Replaces duplicated try/except blocks across blueprints. Uses shared.load_yaml() for error collection. |
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [embeddings](/docs/generated/web-embeddings) | calls | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [search](/docs/generated/web-search) | calls | Tantivy BM25 full-text search engine — indexes all YAML/Markdown files, provides ranked search with snippets |
| [search_utils](/docs/generated/web-search_utils) | calls | Watchtower search utilities: full-text search across tasks, learnings, decisions for the search page. |
| [decisions](/docs/generated/web-templates-decisions) | renders | Watchtower UI page: Decisions |
| [learnings-template](/docs/generated/learnings-template) | renders | Render learnings table, practices section, and navigation for the /learnings page. |
| [gaps](/docs/generated/web-templates-gaps) | renders | Watchtower UI page: Gaps |
| [search](/docs/generated/web-templates-search) | renders | Watchtower UI page: Search |
| [feedback_analytics](/docs/generated/web-templates-feedback_analytics) | renders | Jinja2 template for feedback analytics page. Displays handover quality feedback trends and session statistics. |
| [patterns](/docs/generated/web-templates-patterns) | renders | Watchtower UI page: Patterns |
| [graduation](/docs/generated/web-templates-graduation) | renders | Watchtower UI page: Graduation |
| [patterns-data](/docs/generated/patterns-data) | calls | Stores failure, success, and workflow patterns discovered during project work. |
| [gaps](/docs/generated/lib-gaps) | calls | TODO: describe what this component does |

## Used By (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [search](/docs/generated/web-search) | used-by | Tantivy BM25 full-text search engine — indexes all YAML/Markdown files, provides ranked search with snippets |
| [chat](/docs/generated/web-static-js-chat) | called-by | Ask AI chat tab JavaScript — streaming SSE client, conversation state management, save/load conversations, provider/model switching |
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [search](/docs/generated/web-search) | imported_by_by | Tantivy BM25 full-text search engine — indexes all YAML/Markdown files, provides ranked search with snippets |
| [chat](/docs/generated/web-static-js-chat) | called_by | Ask AI chat tab JavaScript — streaming SSE client, conversation state management, save/load conversations, provider/model switching |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-discovery.yaml`*
*Last verified: 2026-04-05*
