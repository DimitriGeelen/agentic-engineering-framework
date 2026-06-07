# audit_stale_arc_warning

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/audit_stale_arc_warning.bats`

## What It Does

T-1855 (T-NEW-7): stale-arc audit warning.
For each arc with status: in-progress, audit WARNs when no commit in the
last FW_STALE_ARC_DAYS days (default 30) has touched any task with matching
arc_id: (slug or arc-NNN form). Silent on draft/closed/abandoned arcs and
on zero-population arcs. WARN-only, never blocks (T-1846 §4 D4, audit exit
≤ 1). Symmetric to T-1856 anchor existence check.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | tests | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-audit_stale_arc_warning.yaml`*
*Last verified: 2026-05-16*
