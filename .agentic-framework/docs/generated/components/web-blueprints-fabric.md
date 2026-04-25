# fabric

> Flask blueprint: Fabric

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/fabric.py`

## What It Does

In consumer projects, PROJECT_ROOT is .agentic-framework/ — fabric data lives at the parent.
In the framework repo itself, PROJECT_ROOT is the actual root.

### Framework Reference

The Component Fabric (`.fabric/`) is a structural topology map of every significant file — each component has a YAML card in `.fabric/components/` with id, name, type, subsystem, location, purpose, interfaces, depends_on, depended_by.

**When to use:** before modifying a file → `fw fabric deps <path>`; before committing → `fw fabric blast-radius [ref]`; after creating a new file → `fw fabric register <path>`; periodic health → `fw fabric drift` (detects unregistered/orphaned/stale). Also: `fw fabric overview` for the subsystem summary, `fw fabric impact <path>` for the full downstream chain, `

*(truncated — see CLAUDE.md for full section)*

## Dependencies (4)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | calls |
| `web/templates/fabric.html` | renders |
| `web/templates/fabric_detail.html` | renders |
| `web/templates/fabric_explorer.html` | renders |

## Used By (7)

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
