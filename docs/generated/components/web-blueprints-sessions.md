# sessions

> Flask blueprint that renders the terminal session management page listing active and historical sessions

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/sessions.py`

## What It Does

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [registry](/docs/generated/web-terminal-registry) | calls | Provides CRUD operations and YAML file persistence for terminal session records stored in .context/sessions/ |
| [sessions](/docs/generated/web-templates-sessions) | renders | Jinja2 template rendering the sessions management page with session cards showing provider, status, and metadata |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |

## Related

### Tasks
- T-983: Watchtower sessions page — list active terminal sessions with status and controls

---
*Auto-generated from Component Fabric. Card: `web-blueprints-sessions.yaml`*
*Last verified: 2026-04-06*
