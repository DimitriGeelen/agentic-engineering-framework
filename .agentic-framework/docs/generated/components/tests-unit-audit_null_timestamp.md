# audit_null_timestamp

> Regression test — audit.sh METRICS_EOF heredoc must not crash when .context/project/metrics-history.yaml contains a null timestamp. Origin: handover S-2026-0423-1623 AttributeError: 'NoneType' at <stdin>:108.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/audit_null_timestamp.bats`

**Tags:** `test`, `regression`, `audit`, `T-1402`

## What It Does

T-1402: audit.sh METRICS_EOF heredoc must not crash when
.context/project/metrics-history.yaml contains an entry with null timestamp.
Origin: handover S-2026-0423-1623 emitted
"AttributeError: 'NoneType' object has no attribute 'replace'" at <stdin>:108.

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [metrics-history](/docs/generated/context-project-metrics-history) | reads | Historical metrics snapshots tracking task completion rates, commit velocity, and project health over time. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | tests | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-audit_null_timestamp.yaml`*
*Last verified: 2026-04-24*
