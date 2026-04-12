# fabric_explorer

> Interactive D3.js Fabric Explorer — force-directed graph with subsystem bubbles, component expansion, source/report viewers, search, and pathfinding. 1,584 LOC template with CSS isolation (all: initial) to prevent Pico CSS bleeding.

**Type:** template | **Subsystem:** watchtower | **Location:** `web/templates/fabric_explorer.html`

**Tags:** `d3`, `graph`, `visualization`, `interactive`, `fabric-explorer`

## What It Does

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `web/static/d3.v7.min.js` | calls |
| `web/blueprints/fabric.py` | rendered_by |

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/fabric.py` | used-by |
| `web/blueprints/fabric.py` | rendered_by |

## Related

### Tasks
- T-849: Fix Fabric Explorer double-refresh bug — componentData hoisting + hardcoded OpenClaw data
- T-855: Sync vendored .agentic-framework/ with T-849 through T-854 fixes
- T-865: Fix Fabric Explorer naming — use project_name in title
- T-881: Upgrade consumer projects with T-879 xargs fix and T-880 init improvements

---
*Auto-generated from Component Fabric. Card: `web-templates-fabric_explorer.yaml`*
*Last verified: 2026-03-29*
