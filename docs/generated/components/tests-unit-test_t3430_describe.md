# test_t3430_describe

> T-3430 — the fabric card deriver: what a file says about itself, or a refusal.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_t3430_describe.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [describe](/docs/generated/agents-fabric-lib-describe) | calls | Derive a component card's `purpose` and `subsystem` from the source file itself. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_t3430_describe.yaml`*
*Last verified: 2026-09-22*
