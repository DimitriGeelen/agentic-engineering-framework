# test_designer_registry_ghosts

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/web/test_designer_registry_ghosts.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [designer_registry](/docs/generated/web-designer_registry) | calls | TODO: describe what this component does |
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_pair_draft3_intake](/docs/generated/tests-web-test_pair_draft3_intake) | called_by | T-2590/T-2591 drop-point test for 832's pair-draft #3 byte-fixture: sha-verifies tests/fixtures/832/pair-draft-3.bpmn against its .sha256 pin, compiles via Pass-5, and asserts contract-v0 three-leg taxonomy (RESOLVED silent / GHOST claim-WARN / LEGACY legacy-WARN); skips cleanly while the fixture is absent, with a synthetic three-leg sibling keeping the assertions proven |
| [test_s4_exemplar_intake](/docs/generated/tests-web-test_s4_exemplar_intake) | called_by | Drop-point intake harness for 832's future PICKER-authored S4 exemplar (their T-228): skips until tests/fixtures/832/s4-exemplar.{bpmn,sha256} are delivered, then flips to full asserts — sha pin verify, editor-authorship fingerprint (workflowMeta uuid present, no linkEventThrow/Catch host tags, links ride extensionElements on intermediate throw/catch), Pass-5 three-leg classification vs the live corpus, and per-leg registry outcome via sync_project_refs on a meta-clone store. Synthetic editor-dialect test runs green pre-delivery (T-2593; pattern sibling of test_pair_draft3_intake). |

---
*Auto-generated from Component Fabric. Card: `tests-web-test_designer_registry_ghosts.yaml`*
*Last verified: 2026-07-20*
