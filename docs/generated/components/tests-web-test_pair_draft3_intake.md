# test_pair_draft3_intake

> T-2590/T-2591 drop-point test for 832's pair-draft #3 byte-fixture: sha-verifies tests/fixtures/832/pair-draft-3.bpmn against its .sha256 pin, compiles via Pass-5, and asserts contract-v0 three-leg taxonomy (RESOLVED silent / GHOST claim-WARN / LEGACY legacy-WARN); skips cleanly while the fixture is absent, with a synthetic three-leg sibling keeping the assertions proven

**Type:** script | **Subsystem:** testing | **Location:** `tests/web/test_pair_draft3_intake.py`

**Tags:** `designer`, `offpage-seam`, `832`, `fixture-pin`

## What It Does

Live corpus uuid recommended to 832 for the RESOLVED leg (DM offset 118).

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [bpmn_to_tasks](/docs/generated/tools-bpmn_to_tasks) | calls | TODO: describe what this component does |
| [test_designer_registry_ghosts](/docs/generated/tests-web-test_designer_registry_ghosts) | calls | TODO: describe what this component does |
| [pair-draft-3](/docs/generated/tests-fixtures-832-pair-draft-3) | reads | 832's pair-draft #3 exemplar (their T-219): offpage-seam.bpmn exercising the T-2571 contract-v0 three legs (RESOLVED aef-task-lifecycle 1f9b5f0c / GHOST 22222222 / LEGACY review-map slug). Byte-delivered on the DM rail (offsets 120-121), sha256-pinned by the .sha256 sibling — f9422acd330d240dec384591753782dde940289cc94475f22be96aa1551d0c5c, raw 10062 B. READ-ONLY: any change breaks the cross-agent pin (832 guards the same bytes in their test_corpus_fixture_pins.py). RE-PINNED 2026-08-01 (T-324, rail 366): prior pin 0bc15bfac81d…b691449d / 10014 B carried three <bpmn:linkEventThrow> host elements — not a BPMN element at any spec version. 832 renamed all three to <bpmn:intermediateThrowEvent>, tag-only, six lines, <aef:link> children and host id/name byte-identical. Verified by RECONSTRUCTION not by paste: applied the rename locally, sha matched f9422acd exactly. NOTE the pin's scope (OBS-116) — it answers "did these bytes change", never "are these bytes well-formed"; it was green on the malformed element for its entire life. Element-vocabulary checking belongs at intake, not here. |
| [pair-draft-3](/docs/generated/tests-fixtures-832-pair-draft-3) | calls | 832's pair-draft #3 exemplar (their T-219): offpage-seam.bpmn exercising the T-2571 contract-v0 three legs (RESOLVED aef-task-lifecycle 1f9b5f0c / GHOST 22222222 / LEGACY review-map slug). Byte-delivered on the DM rail (offsets 120-121), sha256-pinned by the .sha256 sibling — f9422acd330d240dec384591753782dde940289cc94475f22be96aa1551d0c5c, raw 10062 B. READ-ONLY: any change breaks the cross-agent pin (832 guards the same bytes in their test_corpus_fixture_pins.py). RE-PINNED 2026-08-01 (T-324, rail 366): prior pin 0bc15bfac81d…b691449d / 10014 B carried three <bpmn:linkEventThrow> host elements — not a BPMN element at any spec version. 832 renamed all three to <bpmn:intermediateThrowEvent>, tag-only, six lines, <aef:link> children and host id/name byte-identical. Verified by RECONSTRUCTION not by paste: applied the rename locally, sha matched f9422acd exactly. NOTE the pin's scope (OBS-116) — it answers "did these bytes change", never "are these bytes well-formed"; it was green on the malformed element for its entire life. Element-vocabulary checking belongs at intake, not here. |

---
*Auto-generated from Component Fabric. Card: `tests-web-test_pair_draft3_intake.yaml`*
*Last verified: 2026-07-21*
