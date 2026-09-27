# designer_api

> Designer gallery-server API (T-2529) — the ``/api/*`` endpoints that 832's shipped 0.2.0 Workflow Designer client already calls.

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/designer_api.py`

## What It Does

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [designer_registry](/docs/generated/web-designer_registry) | calls | Pending-ref registry for off-page workflow connectors (T-2574, T-2571 S2). |
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [designer_registry](/docs/generated/web-designer_registry) | uses | Pending-ref registry for off-page workflow connectors (T-2574, T-2571 S2). |
| [shared](/docs/generated/web-shared) | uses | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |

## Used By (13)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [designer](/docs/generated/web-blueprints-designer) | called_by | Designer blueprint — serves the pinned Workflow Designer build (T-2521). |
| [designer](/docs/generated/web-blueprints-designer) | registered_by | Designer blueprint — serves the pinned Workflow Designer build (T-2521). |
| [designer_registry](/docs/generated/web-designer_registry) | called_by | Pending-ref registry for off-page workflow connectors (T-2574, T-2571 S2). |
| [test_api_version_latest](/docs/generated/tests-web-test_api_version_latest) | uses_by | T-2624: /api/version bare-id resolution — `?id=` alone serves the latest version. |
| [test_designer_api_uuid_identity](/docs/generated/tests-web-test_designer_api_uuid_identity) | uses_by | T-2573 (T-2571 S1): immutable workflow uuid in the designer store. |
| [test_designer_landing](/docs/generated/tests-web-test_designer_landing) | uses_by | T-2589: /designer corpus landing page — server truth first, editor at /designer/app. |
| [test_designer_overlay](/docs/generated/tests-web-test_designer_overlay) | uses_by | T-2630: /designer/overlay wrapper page + landing overlay-link contract. |
| [test_designer_registry_claim](/docs/generated/tests-web-test_designer_registry_claim) | uses_by | T-2575 (T-2571 S6): claim — bind a ghost uuid to a live project. |
| [test_designer_registry_ghosts](/docs/generated/tests-web-test_designer_registry_ghosts) | uses_by | T-2574 (T-2571 S2): pending-ref registry — ghost capture at save. |
| [__init__](/docs/generated/web-blueprints-__init__) | uses_by | Flask blueprint:   Init |
| [designer](/docs/generated/web-blueprints-designer) | uses_by | Designer blueprint — serves the pinned Workflow Designer build (T-2521). |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-designer_api.yaml`*
*Last verified: 2026-07-11*
