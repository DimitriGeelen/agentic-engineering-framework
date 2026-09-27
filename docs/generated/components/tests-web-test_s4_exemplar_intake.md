# test_s4_exemplar_intake

> Drop-point intake harness for 832's future PICKER-authored S4 exemplar (their T-228): skips until tests/fixtures/832/s4-exemplar.{bpmn,sha256} are delivered, then flips to full asserts — sha pin verify, editor-authorship fingerprint (workflowMeta uuid present, no linkEventThrow/Catch host tags, links ride extensionElements on intermediate throw/catch), Pass-5 three-leg classification vs the live corpus, and per-leg registry outcome via sync_project_refs on a meta-clone store. Synthetic editor-dialect test runs green pre-delivery (T-2593; pattern sibling of test_pair_draft3_intake).

**Type:** script | **Subsystem:** tests | **Location:** `tests/web/test_s4_exemplar_intake.py`

**Tags:** `designer`, `832-seam`, `s4`, `drop-point`, `fixture-intake`

## What It Does

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_designer_registry_ghosts](/docs/generated/tests-web-test_designer_registry_ghosts) | calls | T-2574 (T-2571 S2): pending-ref registry — ghost capture at save. |
| [designer_registry](/docs/generated/web-designer_registry) | calls | Pending-ref registry for off-page workflow connectors (T-2574, T-2571 S2). |
| [bpmn_to_tasks](/docs/generated/tools-bpmn_to_tasks) | calls | Child-2 forward compiler (first slice): BPMN process diagram -> AEF task skeletons. |
| [test_designer_registry_ghosts](/docs/generated/tests-web-test_designer_registry_ghosts) | uses | T-2574 (T-2571 S2): pending-ref registry — ghost capture at save. |
| [designer_registry](/docs/generated/web-designer_registry) | uses | Pending-ref registry for off-page workflow connectors (T-2574, T-2571 S2). |

---
*Auto-generated from Component Fabric. Card: `tests-web-test_s4_exemplar_intake.yaml`*
*Last verified: 2026-07-22*
