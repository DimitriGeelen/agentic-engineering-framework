# corpus_conformance

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tools/corpus_conformance.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [enums](/docs/generated/lib-enums) | calls | Single source of truth for framework enumerations — valid statuses, workflow types, horizons, and status transitions. Provides is_valid_status(), is_valid_type(), is_valid_horizon(), is_valid_transition() functions. Replaces hardcoded lists previously duplicated across 6+ files. |
| [corpus_spec](/docs/generated/tools-corpus_spec) | uses | TODO: describe what this component does |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [test_corpus_conformance_registry](/docs/generated/tests-unit-test_corpus_conformance_registry) | called_by | TODO: describe what this component does |
| [corpus_explain](/docs/generated/tools-corpus_explain) | uses_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tools-corpus_conformance.yaml`*
*Last verified: 2026-07-26*
