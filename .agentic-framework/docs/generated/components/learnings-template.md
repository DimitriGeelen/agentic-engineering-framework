# learnings-template

> Render learnings table, practices section, and navigation for the /learnings page.

**Type:** template | **Subsystem:** learnings-pipeline | **Location:** `web/templates/learnings.html`

**Tags:** `learning`, `web`, `watchtower`, `template`, `htmx`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [learnings-route](/docs/generated/learnings-route) | renders | Serve the /learnings page showing all project learnings, patterns, and practices. — _Receives learnings, patterns, practices as template variables_ |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [learnings-route](/docs/generated/learnings-route) | rendered_by | Serve the /learnings page showing all project learnings, patterns, and practices. |
| [discovery_blueprint](/docs/generated/web-blueprints-discovery) | rendered_by | Watchtower discovery page — decisions, learnings, gaps, search, graduation |

---
*Auto-generated from Component Fabric. Card: `learnings-template.yaml`*
*Last verified: 2026-02-20*
