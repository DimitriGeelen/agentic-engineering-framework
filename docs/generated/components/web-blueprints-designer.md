# designer

> Designer blueprint — serves the pinned Workflow Designer build (T-2521).

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/designer.py`

## What It Does

T-2648 (OBS-097): pin + fw binary are FRAMEWORK-owned (vendored for
consumers) — PROJECT_ROOT resolution breaks split-root installs.

## Dependencies (12)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [designer_api](/docs/generated/web-blueprints-designer_api) | calls | Designer gallery-server API (T-2529) — the ``/api/*`` endpoints that 832's shipped 0.2.0 Workflow Designer client already calls. |
| [designer_registry](/docs/generated/web-designer_registry) | calls | Pending-ref registry for off-page workflow connectors (T-2574, T-2571 S2). |
| [designer_ghosts](/docs/generated/web-templates-designer_ghosts) | renders | Designer ghost-card grid, rendered by web/blueprints/designer.py:designer_ghosts. |
| [designer_api](/docs/generated/web-blueprints-designer_api) | registers | Designer gallery-server API (T-2529) — the ``/api/*`` endpoints that 832's shipped 0.2.0 Workflow Designer client already calls. |
| [designer_landing](/docs/generated/web-templates-designer_landing) | renders | Designer landing page corpus-card grid, rendered by web/blueprints/designer.py. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [corpus_overlay](/docs/generated/tools-corpus_overlay) | calls | T-2629 (T-2620 GO, Slice A): live task-state projection onto map carrier uids. |
| [shared](/docs/generated/web-shared) | uses | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [designer_api](/docs/generated/web-blueprints-designer_api) | uses | Designer gallery-server API (T-2529) — the ``/api/*`` endpoints that 832's shipped 0.2.0 Workflow Designer client already calls. |
| [designer_registry](/docs/generated/web-designer_registry) | uses | Pending-ref registry for off-page workflow connectors (T-2574, T-2571 S2). |
| [designer-pin](/docs/generated/policy-designer-pin) | calls | Pinned Workflow Designer build record (T-2521): the AEF-832 integration contract naming the vendored release (tag, sha, artifact) of the 832-Workflow-designer single-file build. Bumped via pull-at-tag protocol, never edited in place. |

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [test_api_overlay](/docs/generated/tests-web-test_api_overlay) | uses_by | T-2629: /api/overlay endpoint contract — status codes + payload shape. |
| [test_designer_overlay](/docs/generated/tests-web-test_designer_overlay) | uses_by | T-2630: /designer/overlay wrapper page + landing overlay-link contract. |
| [__init__](/docs/generated/web-blueprints-__init__) | uses_by | Flask blueprint:   Init |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-designer.yaml`*
*Last verified: 2026-07-10*
