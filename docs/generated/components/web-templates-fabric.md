# fabric

> Watchtower UI page: Fabric

**Type:** template | **Subsystem:** watchtower | **Location:** `web/templates/fabric.html`

## What It Does

### Framework Reference

The Component Fabric (`.fabric/`) is a structural topology map of every significant file — each component has a YAML card in `.fabric/components/` with id, name, type, subsystem, location, purpose, interfaces, depends_on, depended_by.

**When to use:** before modifying a file → `fw fabric deps <path>`; before committing → `fw fabric blast-radius [ref]`; after creating a new file → `fw fabric register <path>`; periodic health → `fw fabric drift` (detects unregistered/orphaned/stale). Also: `fw fabric overview` for the subsystem summary, `fw fabric impact <path>` for the full downstream chain, `

*(truncated — see CLAUDE.md for full section)*

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/fabric.py` | rendered_by |

---
*Auto-generated from Component Fabric. Card: `web-templates-fabric.yaml`*
*Last verified: 2026-02-20*
