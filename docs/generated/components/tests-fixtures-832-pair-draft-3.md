# pair-draft-3

> 832's pair-draft #3 exemplar (their T-219): offpage-seam.bpmn exercising the T-2571 contract-v0 three legs (RESOLVED aef-task-lifecycle 1f9b5f0c / GHOST 22222222 / LEGACY review-map slug). Byte-delivered on the DM rail (offsets 120-121), sha256-pinned by the .sha256 sibling — f9422acd330d240dec384591753782dde940289cc94475f22be96aa1551d0c5c, raw 10062 B. READ-ONLY: any change breaks the cross-agent pin (832 guards the same bytes in their test_corpus_fixture_pins.py). RE-PINNED 2026-08-01 (T-324, rail 366): prior pin 0bc15bfac81d…b691449d / 10014 B carried three <bpmn:linkEventThrow> host elements — not a BPMN element at any spec version. 832 renamed all three to <bpmn:intermediateThrowEvent>, tag-only, six lines, <aef:link> children and host id/name byte-identical. Verified by RECONSTRUCTION not by paste: applied the rename locally, sha matched f9422acd exactly. NOTE the pin's scope (OBS-116) — it answers "did these bytes change", never "are these bytes well-formed"; it was green on the malformed element for its entire life. Element-vocabulary checking belongs at intake, not here.

**Type:** data | **Subsystem:** testing | **Location:** `tests/fixtures/832/pair-draft-3.bpmn`

**Tags:** `designer`, `offpage-seam`, `832`, `fixture-pin`

## What It Does

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_pair_draft3_intake](/docs/generated/tests-web-test_pair_draft3_intake) | reads | T-2590/T-2591 drop-point test for 832's pair-draft #3 byte-fixture: sha-verifies tests/fixtures/832/pair-draft-3.bpmn against its .sha256 pin, compiles via Pass-5, and asserts contract-v0 three-leg taxonomy (RESOLVED silent / GHOST claim-WARN / LEGACY legacy-WARN); skips cleanly while the fixture is absent, with a synthetic three-leg sibling keeping the assertions proven |
| [test_bpmn_frozen_v1_pin](/docs/generated/tests-web-test_bpmn_frozen_v1_pin) | read_by | T-2556 AC3 absent-marker half: frozen-v1 byte-pin of the compile→stage→reconcile pipeline on a NO-kind-marker diagram (832's byte-pinned pair-draft-3 fixture). Pins manifest sha256 golden + all-NEW reconcile so the post-ratification kind= consumption legs (compile stamps kind:, promote refuses documentation) provably keep unmarked diagrams byte-identical. Harness-first pattern (T-2579/T-2590). |
| [test_pair_draft3_intake](/docs/generated/tests-web-test_pair_draft3_intake) | read_by | T-2590/T-2591 drop-point test for 832's pair-draft #3 byte-fixture: sha-verifies tests/fixtures/832/pair-draft-3.bpmn against its .sha256 pin, compiles via Pass-5, and asserts contract-v0 three-leg taxonomy (RESOLVED silent / GHOST claim-WARN / LEGACY legacy-WARN); skips cleanly while the fixture is absent, with a synthetic three-leg sibling keeping the assertions proven |
| [test_bpmn_frozen_v1_pin](/docs/generated/tests-web-test_bpmn_frozen_v1_pin) | called_by | T-2556 AC3 absent-marker half: frozen-v1 byte-pin of the compile→stage→reconcile pipeline on a NO-kind-marker diagram (832's byte-pinned pair-draft-3 fixture). Pins manifest sha256 golden + all-NEW reconcile so the post-ratification kind= consumption legs (compile stamps kind:, promote refuses documentation) provably keep unmarked diagrams byte-identical. Harness-first pattern (T-2579/T-2590). |
| [test_pair_draft3_intake](/docs/generated/tests-web-test_pair_draft3_intake) | called_by | T-2590/T-2591 drop-point test for 832's pair-draft #3 byte-fixture: sha-verifies tests/fixtures/832/pair-draft-3.bpmn against its .sha256 pin, compiles via Pass-5, and asserts contract-v0 three-leg taxonomy (RESOLVED silent / GHOST claim-WARN / LEGACY legacy-WARN); skips cleanly while the fixture is absent, with a synthetic three-leg sibling keeping the assertions proven |

---
*Auto-generated from Component Fabric. Card: `tests-fixtures-832-pair-draft-3.yaml`*
*Last verified: 2026-07-21*
