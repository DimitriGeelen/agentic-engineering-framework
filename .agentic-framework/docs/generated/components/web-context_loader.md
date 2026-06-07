# context_loader

> Centralized YAML loading for context project files (learnings, patterns, decisions, practices, concerns, directives). Replaces duplicated try/except blocks across blueprints. Uses shared.load_yaml() for error collection.

**Type:** script | **Subsystem:** watchtower | **Location:** `web/context_loader.py`

**Tags:** `python`, `yaml`, `context`, `watchtower`, `loading`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |

## Used By (10)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [discovery_blueprint](/docs/generated/web-blueprints-discovery) | calls | Watchtower discovery page — decisions, learnings, gaps, search, graduation |
| [core](/docs/generated/web-blueprints-core) | calls | Flask blueprint: Core |
| [metrics](/docs/generated/web-blueprints-metrics) | calls | Flask blueprint: Metrics |
| [risks](/docs/generated/web-blueprints-risks) | calls | Flask blueprint 'risks' serving routes: /risks |
| [learnings-route](/docs/generated/learnings-route) | called_by | Serve the /learnings page showing all project learnings, patterns, and practices. |
| [core](/docs/generated/web-blueprints-core) | called_by | Flask blueprint: Core |
| [metrics](/docs/generated/web-blueprints-metrics) | called_by | Flask blueprint: Metrics |
| [risks](/docs/generated/web-blueprints-risks) | called_by | Flask blueprint 'risks' serving routes: /risks |
| [quality](/docs/generated/web-blueprints-quality) | called_by | Flask blueprint: Quality |
| [discovery_blueprint](/docs/generated/web-blueprints-discovery) | called_by | Watchtower discovery page — decisions, learnings, gaps, search, graduation |

---
*Auto-generated from Component Fabric. Card: `web-context_loader.yaml`*
*Last verified: 2026-03-11*
