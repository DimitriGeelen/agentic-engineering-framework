# fabric

> Watchtower UI page: Fabric

**Type:** template | **Subsystem:** watchtower | **Location:** `web/templates/fabric.html`

## What It Does

### Framework Reference

The Component Fabric (`.fabric/`) is a structural topology map of every significant file in the framework. It enables impact analysis, dependency tracking, and onboarding.

### When to Use

- **Before modifying a file:** `fw fabric deps <path>` — see what depends on it and what it depends on
- **Before committing:** `fw fabric blast-radius` — see downstream impact of your changes
- **After creating new files:** `fw fabric register <path>` — create a component card
- **Periodic health check:** `fw fabric drift` — detect unregistered, orphaned, or stale components

### Key Commands

*(truncated — see CLAUDE.md for full section)*

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/fabric.py` | rendered_by |

## Related

### Tasks
- T-215: Component Fabric — Watchtower UI page (visual browser + graph)
- T-227: Fix fabric page — subsystem cards link to themselves, dropdown filters broken

---
*Auto-generated from Component Fabric. Card: `web-templates-fabric.yaml`*
*Last verified: 2026-02-20*
