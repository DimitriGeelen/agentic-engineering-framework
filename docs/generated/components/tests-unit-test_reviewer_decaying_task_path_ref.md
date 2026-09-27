# test_reviewer_decaying_task_path_ref

> T-3274: pin the decaying-`.tasks/active/` verification-reference detector.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_reviewer_decaying_task_path_ref.py`

## What It Does

The task doing the referencing — its own location is what anchors the
detector's walk up to `.tasks/`.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [__init__](/docs/generated/lib-reviewer-__init__) | calls | Reviewer agent (T-1443 v1.0). |
| [__init__](/docs/generated/lib-reviewer-__init__) | uses | Reviewer agent (T-1443 v1.0). |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_reviewer_decaying_task_path_ref.yaml`*
*Last verified: 2026-09-04*
