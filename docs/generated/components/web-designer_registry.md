# designer_registry

> Pending-ref registry for off-page workflow connectors (T-2574, T-2571 S2).

**Type:** script | **Subsystem:** watchtower | **Location:** `web/designer_registry.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [designer_api](/docs/generated/web-blueprints-designer_api) | calls | Designer gallery-server API (T-2529) — the ``/api/*`` endpoints that 832's shipped 0.2.0 Workflow Designer client already calls. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (10)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_designer_registry_claim](/docs/generated/tests-web-test_designer_registry_claim) | called_by | T-2575 (T-2571 S6): claim — bind a ghost uuid to a live project. |
| [test_designer_registry_ghosts](/docs/generated/tests-web-test_designer_registry_ghosts) | called_by | T-2574 (T-2571 S2): pending-ref registry — ghost capture at save. |
| [designer](/docs/generated/web-blueprints-designer) | called_by | Designer blueprint — serves the pinned Workflow Designer build (T-2521). |
| [designer_api](/docs/generated/web-blueprints-designer_api) | called_by | Designer gallery-server API (T-2529) — the ``/api/*`` endpoints that 832's shipped 0.2.0 Workflow Designer client already calls. |
| [test_s4_exemplar_intake](/docs/generated/tests-web-test_s4_exemplar_intake) | called_by | Drop-point intake harness for 832's future PICKER-authored S4 exemplar (their T-228): skips until tests/fixtures/832/s4-exemplar.{bpmn,sha256} are delivered, then flips to full asserts — sha pin verify, editor-authorship fingerprint (workflowMeta uuid present, no linkEventThrow/Catch host tags, links ride extensionElements on intermediate throw/catch), Pass-5 three-leg classification vs the live corpus, and per-leg registry outcome via sync_project_refs on a meta-clone store. Synthetic editor-dialect test runs green pre-delivery (T-2593; pattern sibling of test_pair_draft3_intake). |
| [test_designer_registry_claim](/docs/generated/tests-web-test_designer_registry_claim) | uses_by | T-2575 (T-2571 S6): claim — bind a ghost uuid to a live project. |
| [test_designer_registry_ghosts](/docs/generated/tests-web-test_designer_registry_ghosts) | uses_by | T-2574 (T-2571 S2): pending-ref registry — ghost capture at save. |
| [test_s4_exemplar_intake](/docs/generated/tests-web-test_s4_exemplar_intake) | uses_by | Drop-point intake harness for 832's future PICKER-authored S4 exemplar (their T-228): skips until tests/fixtures/832/s4-exemplar.{bpmn,sha256} are delivered, then flips to full asserts — sha pin verify, editor-authorship fingerprint (workflowMeta uuid present, no linkEventThrow/Catch host tags, links ride extensionElements on intermediate throw/catch), Pass-5 three-leg classification vs the live corpus, and per-leg registry outcome via sync_project_refs on a meta-clone store. Synthetic editor-dialect test runs green pre-delivery (T-2593; pattern sibling of test_pair_draft3_intake). |
| [designer](/docs/generated/web-blueprints-designer) | uses_by | Designer blueprint — serves the pinned Workflow Designer build (T-2521). |
| [designer_api](/docs/generated/web-blueprints-designer_api) | uses_by | Designer gallery-server API (T-2529) — the ``/api/*`` endpoints that 832's shipped 0.2.0 Workflow Designer client already calls. |

---
*Auto-generated from Component Fabric. Card: `web-designer_registry.yaml`*
*Last verified: 2026-07-20*
