# underpopulated

> Scan component cards for the under-populated class — a card that says nothing.

**Type:** script | **Subsystem:** component-fabric | **Location:** `agents/fabric/lib/underpopulated.py`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [describe](/docs/generated/agents-fabric-lib-describe) | uses | Derive a component card's `purpose` and `subsystem` from the source file itself. |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [t3430_fabric_audit_doctor](/docs/generated/tests-unit-t3430_fabric_audit_doctor) | tests_by | T-3430: the audit + doctor surfaces for under-populated fabric cards. |

---
*Auto-generated from Component Fabric. Card: `agents-fabric-lib-underpopulated.yaml`*
*Last verified: 2026-09-22*
