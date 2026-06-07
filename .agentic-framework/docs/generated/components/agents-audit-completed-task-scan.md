# completed-task-scan

> Single-pass scan of completed task files that checks for missing episodic summaries, missing research artifacts, and unchecked acceptance criteria

**Type:** script | **Subsystem:** audit | **Location:** `agents/audit/completed-task-scan.py`

## What It Does

## Used By (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [audit_scan](/docs/generated/tests-unit-audit_scan) | called_by | TODO: describe what this component does |
| [audit_scan](/docs/generated/tests-unit-audit_scan) | tests_by | TODO: describe what this component does |
| [audit_ctl028_completed_status_consistency](/docs/generated/tests-unit-audit_ctl028_completed_status_consistency) | called_by | TODO: describe what this component does |
| [audit_ctl028_completed_status_consistency](/docs/generated/tests-unit-audit_ctl028_completed_status_consistency) | tests_by | TODO: describe what this component does |
| [audit_ctl030_completed_horizon_drift](/docs/generated/tests-unit-audit_ctl030_completed_horizon_drift) | called_by | TODO: describe what this component does |
| [audit_ctl030_completed_horizon_drift](/docs/generated/tests-unit-audit_ctl030_completed_horizon_drift) | tests_by | TODO: describe what this component does |

## Related

### Tasks
- T-955: Audit loop merge — combine 10 loops into 3 passes (T-860 Phase 1)

---
*Auto-generated from Component Fabric. Card: `agents-audit-completed-task-scan.yaml`*
*Last verified: 2026-04-06*
