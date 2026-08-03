# test_bpmn_frozen_v1_pin

> T-2556 AC3 absent-marker half: frozen-v1 byte-pin of the compile→stage→reconcile pipeline on a NO-kind-marker diagram (832's byte-pinned pair-draft-3 fixture). Pins manifest sha256 golden + all-NEW reconcile so the post-ratification kind= consumption legs (compile stamps kind:, promote refuses documentation) provably keep unmarked diagrams byte-identical. Harness-first pattern (T-2579/T-2590).

**Type:** test | **Subsystem:** testing | **Location:** `tests/web/test_bpmn_frozen_v1_pin.py`

**Tags:** `designer`, `offpage-seam`, `832`, `frozen-v1`, `kind-marker`

## What It Does

Golden: sha256 of the manifest.yaml emitted by write_proposals() for the
byte-pinned fixture staged under the relative diagram path below. The staged
output is fully deterministic (no timestamps), so this is a byte-exact pin.

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [bpmn_to_tasks](/docs/generated/tools-bpmn_to_tasks) | calls | TODO: describe what this component does |
| [bpmn_promote](/docs/generated/tools-bpmn_promote) | calls | TODO: describe what this component does |
| [pair-draft-3](/docs/generated/tests-fixtures-832-pair-draft-3) | reads | 832's pair-draft #3 exemplar (their T-219): offpage-seam.bpmn exercising the T-2571 contract-v0 three legs (RESOLVED aef-task-lifecycle 1f9b5f0c / GHOST 22222222 / LEGACY review-map slug). Byte-delivered on the DM rail (offsets 120-121), sha256-pinned by the .sha256 sibling — f9422acd330d240dec384591753782dde940289cc94475f22be96aa1551d0c5c, raw 10062 B. READ-ONLY: any change breaks the cross-agent pin (832 guards the same bytes in their test_corpus_fixture_pins.py). RE-PINNED 2026-08-01 (T-324, rail 366): prior pin 0bc15bfac81d…b691449d / 10014 B carried three <bpmn:linkEventThrow> host elements — not a BPMN element at any spec version. 832 renamed all three to <bpmn:intermediateThrowEvent>, tag-only, six lines, <aef:link> children and host id/name byte-identical. Verified by RECONSTRUCTION not by paste: applied the rename locally, sha matched f9422acd exactly. NOTE the pin's scope (OBS-116) — it answers "did these bytes change", never "are these bytes well-formed"; it was green on the malformed element for its entire life. Element-vocabulary checking belongs at intake, not here. |
| [pair-draft-3](/docs/generated/tests-fixtures-832-pair-draft-3) | calls | 832's pair-draft #3 exemplar (their T-219): offpage-seam.bpmn exercising the T-2571 contract-v0 three legs (RESOLVED aef-task-lifecycle 1f9b5f0c / GHOST 22222222 / LEGACY review-map slug). Byte-delivered on the DM rail (offsets 120-121), sha256-pinned by the .sha256 sibling — f9422acd330d240dec384591753782dde940289cc94475f22be96aa1551d0c5c, raw 10062 B. READ-ONLY: any change breaks the cross-agent pin (832 guards the same bytes in their test_corpus_fixture_pins.py). RE-PINNED 2026-08-01 (T-324, rail 366): prior pin 0bc15bfac81d…b691449d / 10014 B carried three <bpmn:linkEventThrow> host elements — not a BPMN element at any spec version. 832 renamed all three to <bpmn:intermediateThrowEvent>, tag-only, six lines, <aef:link> children and host id/name byte-identical. Verified by RECONSTRUCTION not by paste: applied the rename locally, sha matched f9422acd exactly. NOTE the pin's scope (OBS-116) — it answers "did these bytes change", never "are these bytes well-formed"; it was green on the malformed element for its entire life. Element-vocabulary checking belongs at intake, not here. |

---
*Auto-generated from Component Fabric. Card: `tests-web-test_bpmn_frozen_v1_pin.yaml`*
*Last verified: 2026-07-21*
