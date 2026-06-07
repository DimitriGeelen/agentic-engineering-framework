# audit

> Unit tests for agents/audit/audit.sh (11 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/audit.bats`

**Tags:** `audit`, `bats`, `unit-test`

## What It Does

Unit tests for agents/audit/audit.sh
Origin: T-924

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | tests | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |

## Related

### Tasks
- T-924: Add unit tests for agents/audit/audit.sh

---
*Auto-generated from Component Fabric. Card: `tests-unit-audit.yaml`*
*Last verified: 2026-04-05*
