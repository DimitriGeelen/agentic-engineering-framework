# audit_graduation_counter

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/audit_graduation_counter.bats`

## What It Does

T-2677 — audit graduation counter shape-agnostic (dead >=20 branch).
The old '^  - id: L-' grep counted 0 against the real learnings.yaml
(column-0 dash entries + no-dash legacy entries), so the >=20 threshold
branch — the only programmatic caller of `fw promote suggest` — never
fired. Same file-shape-blindness family as T-2676 (harvest greps) and
T-2672 (resolve.sh emit-indent); different site and mechanism
(count-then-threshold vs extract-values).
The counter line lives inline in audit.sh section 9; these tests pin the
REGEX ITSELF against fixture files plus the live-file floor, so a
regression to a fixed-shape grep fails here before it dies in the field.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | tests | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-audit_graduation_counter.yaml`*
*Last verified: 2026-07-29*
