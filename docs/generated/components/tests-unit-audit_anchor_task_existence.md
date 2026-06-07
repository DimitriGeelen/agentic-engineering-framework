# audit_anchor_task_existence

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/audit_anchor_task_existence.bats`

## What It Does

T-1856 (T-NEW-8): anchor_task existence audit check.
When an arc YAML declares anchor_task: T-XXX and that task does not exist
in .tasks/{active,completed}/, audit emits a WARN — never FAIL.
Symmetric to T-1849's arc_id validation (which guards task→arc); this
guards arc→task. Matches T-1846 §4 D4 (warn not block).

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | tests | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-audit_anchor_task_existence.yaml`*
*Last verified: 2026-05-16*
