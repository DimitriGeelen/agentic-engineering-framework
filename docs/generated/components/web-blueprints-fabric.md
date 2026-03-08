# fabric

> Flask blueprint: Fabric

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/fabric.py`

## What It Does

mtime-based cache for component loading

### Framework Reference

The Component Fabric (`.fabric/`) is a structural topology map of every significant file in the framework. It enables impact analysis, dependency tracking, and onboarding.

### When to Use

- **Before modifying a file:** `fw fabric deps <path>` — see what depends on it and what it depends on
- **Before committing:** `fw fabric blast-radius` — see downstream impact of your changes
- **After creating new files:** `fw fabric register <path>` — create a component card
- **Periodic health check:** `fw fabric drift` — detect unregistered, orphaned, or stale components

### Key Commands

*(truncated — see CLAUDE.md for full section)*

## Dependencies (4)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | calls |
| `web/templates/fabric.html` | renders |
| `web/templates/fabric_detail.html` | renders |
| `web/templates/fabric_graph.html` | renders |

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `web/app.py` | called_by |
| `web/app.py` | registered_by |

## Related

### Tasks
- T-215: Component Fabric — Watchtower UI page (visual browser + graph)
- T-220: Fabric component detail — inline source code viewer
- T-233: Improve fabric graph layout
- T-251: Fix C-XXX display in fabric detail page
- T-252: Fix unresolved C-XXX/F-XXX IDs in filtered fabric graph

---
*Auto-generated from Component Fabric. Card: `web-blueprints-fabric.yaml`*
*Last verified: 2026-02-20*
