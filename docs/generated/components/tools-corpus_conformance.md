# corpus_conformance

> Map-conformance rail — corpus map assertions vs the enforced state machine.

**Type:** script | **Subsystem:** framework-core | **Location:** `tools/corpus_conformance.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [enums](/docs/generated/lib-enums) | calls | Single source of truth for framework enumerations — valid statuses, workflow types, horizons, and status transitions. Provides is_valid_status(), is_valid_type(), is_valid_horizon(), is_valid_transition() functions. Replaces hardcoded lists previously duplicated across 6+ files. |
| [corpus_spec](/docs/generated/tools-corpus_spec) | uses | corpus_spec — declarative spec ⇄ designer-corpus BPMN (T-2603, arc T-2602 GO). |

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [test_corpus_conformance_registry](/docs/generated/tests-unit-test_corpus_conformance_registry) | called_by | T-2654 (T-2652 GO slice 1): registry-driven conformance checker mechanics. |
| [corpus_explain](/docs/generated/tools-corpus_explain) | uses_by | T-2622: agent retrieval seam — corpus maps readable without a browser. |
| [aef_meta_census](/docs/generated/tools-aef_meta_census) | called_by | aef:meta key census — T-2871. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |

---
*Auto-generated from Component Fabric. Card: `tools-corpus_conformance.yaml`*
*Last verified: 2026-07-26*
