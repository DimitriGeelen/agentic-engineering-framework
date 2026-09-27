# corpus_overlay

> T-2629 (T-2620 GO, Slice A): live task-state projection onto map carrier uids.

**Type:** script | **Subsystem:** framework-core | **Location:** `tools/corpus_overlay.py`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [corpus_spec](/docs/generated/tools-corpus_spec) | uses | corpus_spec — declarative spec ⇄ designer-corpus BPMN (T-2603, arc T-2602 GO). |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [designer](/docs/generated/web-blueprints-designer) | called_by | Designer blueprint — serves the pinned Workflow Designer build (T-2521). |
| [test_corpus_overlay](/docs/generated/tests-unit-test_corpus_overlay) | called_by | Unit pins for the overlay projection profiles (T-2629/T-2634): bucket routing, severity ladder + queue floor, phantom-uid filter, canonical wire shape |
| [aef_meta_census](/docs/generated/tools-aef_meta_census) | called_by | aef:meta key census — T-2871. |

---
*Auto-generated from Component Fabric. Card: `tools-corpus_overlay.yaml`*
*Last verified: 2026-07-27*
