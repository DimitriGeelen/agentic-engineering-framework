# learnings-route

> Serve the /learnings page showing all project learnings, patterns, and practices.

**Type:** route | **Subsystem:** learnings-pipeline | **Location:** `web/blueprints/discovery.py`

**Tags:** `learning`, `web`, `watchtower`, `discovery`

## What It Does

## Dependencies (15)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [learnings-data](/docs/generated/learnings-data) | reads | Persistent store of all project learnings. Read by web UI and audit. Written by add-learning command. |
| [patterns-data](/docs/generated/patterns-data) | reads | Stores failure, success, and workflow patterns discovered during project work. |
| [learnings-template](/docs/generated/learnings-template) | renders | Render learnings table, practices section, and navigation for the /learnings page. |
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [decisions](/docs/generated/web-templates-decisions) | renders | Watchtower UI page: Decisions |
| [gaps](/docs/generated/web-templates-gaps) | renders | Watchtower UI page: Gaps |
| [search](/docs/generated/web-templates-search) | renders | Watchtower UI page: Search |
| [patterns](/docs/generated/web-templates-patterns) | renders | Watchtower UI page: Patterns |
| [graduation](/docs/generated/web-templates-graduation) | renders | Watchtower UI page: Graduation |
| [context_loader](/docs/generated/web-context_loader) | calls | Centralized YAML loading for context project files (learnings, patterns, decisions, practices, concerns, directives). Replaces duplicated try/except blocks across blueprints. Uses shared.load_yaml() for error collection. |
| [embeddings](/docs/generated/web-embeddings) | calls | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [search](/docs/generated/web-search) | calls | Tantivy BM25 full-text search engine — indexes all YAML/Markdown files, provides ranked search with snippets |
| [search_utils](/docs/generated/web-search_utils) | calls | Watchtower search utilities: full-text search across tasks, learnings, decisions for the search page. |
| [feedback_analytics](/docs/generated/web-templates-feedback_analytics) | renders | Jinja2 template for feedback analytics page. Displays handover quality feedback trends and session statistics. |
| [patterns-data](/docs/generated/patterns-data) | calls | Stores failure, success, and workflow patterns discovered during project work. |

## Used By (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [learnings-template](/docs/generated/learnings-template) | htmx | Render learnings table, practices section, and navigation for the /learnings page. — _Template links back to /patterns via hx-get_ |
| [app](/docs/generated/web-app) | called_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [app](/docs/generated/web-app) | registered_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [learnings-template](/docs/generated/learnings-template) | rendered_by | Render learnings table, practices section, and navigation for the /learnings page. |
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |

---
*Auto-generated from Component Fabric. Card: `learnings-route.yaml`*
*Last verified: 2026-02-20*
