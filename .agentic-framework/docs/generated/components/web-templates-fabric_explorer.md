# fabric_explorer

> Interactive D3.js Fabric Explorer — force-directed graph with subsystem bubbles, component expansion, source/report viewers, search, and pathfinding. 1,584 LOC template with CSS isolation (all: initial) to prevent Pico CSS bleeding.

**Type:** template | **Subsystem:** watchtower | **Location:** `web/templates/fabric_explorer.html`

**Tags:** `d3`, `graph`, `visualization`, `interactive`, `fabric-explorer`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [d3.v7.min](/docs/generated/web-static-d3) | calls | Vendored D3.js v7 library — force-directed graph, SVG rendering, zoom/pan. Used by fabric_explorer.html. No CDN dependency. |
| [fabric](/docs/generated/web-blueprints-fabric) | rendered_by | Flask blueprint: Fabric |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fabric](/docs/generated/web-blueprints-fabric) | used-by | Flask blueprint: Fabric |
| [fabric](/docs/generated/web-blueprints-fabric) | rendered_by | Flask blueprint: Fabric |

## Related

### Tasks
- T-849: Fix Fabric Explorer double-refresh bug — componentData hoisting + hardcoded OpenClaw data
- T-855: Sync vendored .agentic-framework/ with T-849 through T-854 fixes
- T-865: Fix Fabric Explorer naming — use project_name in title
- T-881: Upgrade consumer projects with T-879 xargs fix and T-880 init improvements

---
*Auto-generated from Component Fabric. Card: `web-templates-fabric_explorer.yaml`*
*Last verified: 2026-03-29*
