# aef_meta_census

> aef:meta key census — T-2871.

**Type:** script | **Subsystem:** framework-core | **Location:** `tools/aef_meta_census.py`

## What It Does

Frozen v1 governance meta-keys (aef-bpmn-mapping-v1 Part I §2, pinned T-2869).

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [corpus_conformance](/docs/generated/tools-corpus_conformance) | calls | Map-conformance rail — corpus map assertions vs the enforced state machine. |
| [corpus_overlay](/docs/generated/tools-corpus_overlay) | calls | T-2629 (T-2620 GO, Slice A): live task-state projection onto map carrier uids. |
| [bpmn_to_tasks](/docs/generated/tools-bpmn_to_tasks) | calls | Child-2 forward compiler (first slice): BPMN process diagram -> AEF task skeletons. |

---
*Auto-generated from Component Fabric. Card: `tools-aef_meta_census.yaml`*
*Last verified: 2026-09-03*
