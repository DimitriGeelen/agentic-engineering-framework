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

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [fabric](/docs/generated/web-templates-fabric) | renders | Watchtower UI page: Fabric |
| [fabric_detail](/docs/generated/web-templates-fabric_detail) | renders | Watchtower UI page: Fabric Detail |
| [fabric_explorer](/docs/generated/web-templates-fabric_explorer) | renders | Interactive D3.js Fabric Explorer — force-directed graph with subsystem bubbles, component expansion, source/report viewers, search, and pathfinding. 1,584 LOC template with CSS isolation (all: initial) to prevent Pico CSS bleeding. |

## Used By (9)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | called_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [app](/docs/generated/web-app) | registered_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [fabric_explorer](/docs/generated/web-templates-fabric_explorer) | used-by | Interactive D3.js Fabric Explorer — force-directed graph with subsystem bubbles, component expansion, source/report viewers, search, and pathfinding. 1,584 LOC template with CSS isolation (all: initial) to prevent Pico CSS bleeding. |
| [fabric_explorer](/docs/generated/web-templates-fabric_explorer) | rendered_by_by | Interactive D3.js Fabric Explorer — force-directed graph with subsystem bubbles, component expansion, source/report viewers, search, and pathfinding. 1,584 LOC template with CSS isolation (all: initial) to prevent Pico CSS bleeding. |
| [test_api_fabric_source](/docs/generated/tests-playwright-test_api_fabric_source) | called_by | Playwright tests for fabric file APIs (T-1025). |
| [test_fabric_detail](/docs/generated/tests-playwright-test_fabric_detail) | called_by | Playwright tests for fabric component detail page (T-1041). |

## Related

### Tasks
- T-849: Fix Fabric Explorer double-refresh bug — componentData hoisting + hardcoded OpenClaw data
- T-853: Enrich Fabric Explorer subsystem descriptions from component purpose fields
- T-855: Sync vendored .agentic-framework/ with T-849 through T-854 fixes

---
*Auto-generated from Component Fabric. Card: `web-blueprints-fabric.yaml`*
*Last verified: 2026-02-20*
