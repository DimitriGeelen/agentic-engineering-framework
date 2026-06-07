# risks

> Flask blueprint 'risks' serving routes: /risks

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/risks.py`

## What It Does

Split by type

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [risks](/docs/generated/web-templates-risks) | renders | Watchtower UI page: Risks |
| [context_loader](/docs/generated/web-context_loader) | calls | Centralized YAML loading for context project files (learnings, patterns, decisions, practices, concerns, directives). Replaces duplicated try/except blocks across blueprints. Uses shared.load_yaml() for error collection. |
| [controls](/docs/generated/context-project-controls) | calls | Control register tracking framework enforcement mechanisms (gates, hooks, checks) and their implementation status. |

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | called_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [app](/docs/generated/web-app) | registered_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-risks.yaml`*
*Last verified: 2026-02-20*
