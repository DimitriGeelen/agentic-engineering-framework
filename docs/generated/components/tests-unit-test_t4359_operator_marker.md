# test_t4359_operator_marker

> T-4359 (GitHub #102) — the risk carve-outs were found only through English regexes, so a Human criterion written in another language matched none of them and went to an AI reviewer.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_t4359_operator_marker.py`

## What It Does

The defect, pinned: without the tag a non-English irreversible act is not
recognised. This documents why the tag exists; it is not the desired state.

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_t4359_operator_marker.yaml`*
*Last verified: 2026-11-11*
