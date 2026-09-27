# test_designer_registry_ghosts

> T-2574 (T-2571 S2): pending-ref registry — ghost capture at save.

**Type:** script | **Subsystem:** tests | **Location:** `tests/web/test_designer_registry_ghosts.py`

## What It Does

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [designer_registry](/docs/generated/web-designer_registry) | calls | Pending-ref registry for off-page workflow connectors (T-2574, T-2571 S2). |
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [designer_registry](/docs/generated/web-designer_registry) | uses | Pending-ref registry for off-page workflow connectors (T-2574, T-2571 S2). |
| [app](/docs/generated/web-app) | uses | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [designer_api](/docs/generated/web-blueprints-designer_api) | uses | Designer gallery-server API (T-2529) — the ``/api/*`` endpoints that 832's shipped 0.2.0 Workflow Designer client already calls. |

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_pair_draft3_intake](/docs/generated/tests-web-test_pair_draft3_intake) | called_by | T-2590/T-2591 drop-point test for 832's pair-draft #3 byte-fixture: sha-verifies tests/fixtures/832/pair-draft-3.bpmn against its .sha256 pin, compiles via Pass-5, and asserts contract-v0 three-leg taxonomy (RESOLVED silent / GHOST claim-WARN / LEGACY legacy-WARN); skips cleanly while the fixture is absent, with a synthetic three-leg sibling keeping the assertions proven |
| [test_s4_exemplar_intake](/docs/generated/tests-web-test_s4_exemplar_intake) | called_by | Drop-point intake harness for 832's future PICKER-authored S4 exemplar (their T-228): skips until tests/fixtures/832/s4-exemplar.{bpmn,sha256} are delivered, then flips to full asserts — sha pin verify, editor-authorship fingerprint (workflowMeta uuid present, no linkEventThrow/Catch host tags, links ride extensionElements on intermediate throw/catch), Pass-5 three-leg classification vs the live corpus, and per-leg registry outcome via sync_project_refs on a meta-clone store. Synthetic editor-dialect test runs green pre-delivery (T-2593; pattern sibling of test_pair_draft3_intake). |
| [test_designer_registry_claim](/docs/generated/tests-web-test_designer_registry_claim) | uses_by | T-2575 (T-2571 S6): claim — bind a ghost uuid to a live project. |
| [test_pair_draft3_intake](/docs/generated/tests-web-test_pair_draft3_intake) | uses_by | T-2590/T-2591 drop-point test for 832's pair-draft #3 byte-fixture: sha-verifies tests/fixtures/832/pair-draft-3.bpmn against its .sha256 pin, compiles via Pass-5, and asserts contract-v0 three-leg taxonomy (RESOLVED silent / GHOST claim-WARN / LEGACY legacy-WARN); skips cleanly while the fixture is absent, with a synthetic three-leg sibling keeping the assertions proven |
| [test_s4_exemplar_intake](/docs/generated/tests-web-test_s4_exemplar_intake) | uses_by | Drop-point intake harness for 832's future PICKER-authored S4 exemplar (their T-228): skips until tests/fixtures/832/s4-exemplar.{bpmn,sha256} are delivered, then flips to full asserts — sha pin verify, editor-authorship fingerprint (workflowMeta uuid present, no linkEventThrow/Catch host tags, links ride extensionElements on intermediate throw/catch), Pass-5 three-leg classification vs the live corpus, and per-leg registry outcome via sync_project_refs on a meta-clone store. Synthetic editor-dialect test runs green pre-delivery (T-2593; pattern sibling of test_pair_draft3_intake). |

---
*Auto-generated from Component Fabric. Card: `tests-web-test_designer_registry_ghosts.yaml`*
*Last verified: 2026-07-20*
