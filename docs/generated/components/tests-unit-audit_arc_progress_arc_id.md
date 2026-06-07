# audit_arc_progress_arc_id

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/audit_arc_progress_arc_id.bats`

## What It Does

T-1875 (T-NEW-11): audit arc-progress fallback unions arc_id frontmatter
with legacy arc:<slug> tag scan.
The fallback at agents/audit/audit.sh:~3619 fires when an arc's
constituent_tasks: [] is empty. T-1813 introduced it as a tag-only scan;
this slice adds arc_id: frontmatter as an equally-valid membership signal
(canonical source-of-truth post-T-1850 migration).
Strategy: this test exercises a self-contained python block whose regex +
scan logic mirrors the production block, against a synthetic .tasks/ tree.
That pins the regex/union behavior independent of the full audit run.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | tests | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-audit_arc_progress_arc_id.yaml`*
*Last verified: 2026-05-17*
