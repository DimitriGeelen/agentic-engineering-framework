# test_importer_fidelity

> T-2882 — a CONTENT census of what our BPMN importer does with what it does not consume.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_importer_fidelity.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [corpus_spec](/docs/generated/tools-corpus_spec) | calls | corpus_spec — declarative spec ⇄ designer-corpus BPMN (T-2603, arc T-2602 GO). |
| [bpmn_to_tasks](/docs/generated/tools-bpmn_to_tasks) | calls | Child-2 forward compiler (first slice): BPMN process diagram -> AEF task skeletons. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_importer_fidelity.yaml`*
*Last verified: 2026-08-09*
