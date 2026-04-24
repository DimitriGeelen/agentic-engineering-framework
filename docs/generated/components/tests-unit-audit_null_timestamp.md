# audit_null_timestamp

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/audit_null_timestamp.bats`

## What It Does

T-1402: audit.sh METRICS_EOF heredoc must not crash when
.context/project/metrics-history.yaml contains an entry with null timestamp.
Origin: handover S-2026-0423-1623 emitted
"AttributeError: 'NoneType' object has no attribute 'replace'" at <stdin>:108.

---
*Auto-generated from Component Fabric. Card: `tests-unit-audit_null_timestamp.yaml`*
*Last verified: 2026-04-23*
