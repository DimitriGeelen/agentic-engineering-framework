# fabric

> Flask blueprint: Fabric

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/fabric.py`

## What It Does

In consumer projects, PROJECT_ROOT is .agentic-framework/ — fabric data lives at the parent.
In the framework repo itself, PROJECT_ROOT is the actual root.

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
| `web/templates/fabric_explorer.html` | renders |

## Used By (6)

| Component | Relationship |
|-----------|-------------|
| `web/app.py` | called_by |
| `web/app.py` | registered_by |
| `web/blueprints/__init__.py` | called_by |
| `web/blueprints/__init__.py` | registered_by |
| `web/templates/fabric_explorer.html` | used-by |
| `web/templates/fabric_explorer.html` | rendered_by_by |

## Related

### Tasks
- T-849: Fix Fabric Explorer double-refresh bug — componentData hoisting + hardcoded OpenClaw data
- T-853: Enrich Fabric Explorer subsystem descriptions from component purpose fields
- T-855: Sync vendored .agentic-framework/ with T-849 through T-854 fixes

---
*Auto-generated from Component Fabric. Card: `web-blueprints-fabric.yaml`*
*Last verified: 2026-02-20*
