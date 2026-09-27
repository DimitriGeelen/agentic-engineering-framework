# test_designer_registry_claim

> T-2575 (T-2571 S6): claim — bind a ghost uuid to a live project.

**Type:** script | **Subsystem:** tests | **Location:** `tests/web/test_designer_registry_claim.py`

## What It Does

## Dependencies (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [designer_registry](/docs/generated/web-designer_registry) | calls | Pending-ref registry for off-page workflow connectors (T-2574, T-2571 S2). |
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [designer_registry](/docs/generated/web-designer_registry) | uses | Pending-ref registry for off-page workflow connectors (T-2574, T-2571 S2). |
| [test_designer_registry_ghosts](/docs/generated/tests-web-test_designer_registry_ghosts) | uses | T-2574 (T-2571 S2): pending-ref registry — ghost capture at save. |
| [app](/docs/generated/web-app) | uses | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [designer_api](/docs/generated/web-blueprints-designer_api) | uses | Designer gallery-server API (T-2529) — the ``/api/*`` endpoints that 832's shipped 0.2.0 Workflow Designer client already calls. |

---
*Auto-generated from Component Fabric. Card: `tests-web-test_designer_registry_claim.yaml`*
*Last verified: 2026-07-20*
