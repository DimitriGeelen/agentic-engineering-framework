# completed-task-scan

> Single-pass scan of completed task files that checks for missing episodic summaries, missing research artifacts, and unchecked acceptance criteria

**Type:** script | **Subsystem:** audit | **Location:** `agents/audit/completed-task-scan.py`

## What It Does

## Used By (10)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [audit_scan](/docs/generated/tests-unit-audit_scan) | called_by | Unit tests for audit scan scripts (T-961) |
| [audit_scan](/docs/generated/tests-unit-audit_scan) | tests_by | Unit tests for audit scan scripts (T-961) |
| [audit_ctl028_completed_status_consistency](/docs/generated/tests-unit-audit_ctl028_completed_status_consistency) | called_by | T-1870 / CTL-028: completed/ frontmatter status consistency |
| [audit_ctl028_completed_status_consistency](/docs/generated/tests-unit-audit_ctl028_completed_status_consistency) | tests_by | T-1870 / CTL-028: completed/ frontmatter status consistency |
| [audit_ctl030_completed_horizon_drift](/docs/generated/tests-unit-audit_ctl030_completed_horizon_drift) | called_by | T-2162 / CTL-030: completed/ stored-horizon drift detection |
| [audit_ctl030_completed_horizon_drift](/docs/generated/tests-unit-audit_ctl030_completed_horizon_drift) | tests_by | T-2162 / CTL-030: completed/ stored-horizon drift detection |
| [audit_ctl012_missing_decide_grandfather](/docs/generated/tests-unit-audit_ctl012_missing_decide_grandfather) | called_by | T-2385: CTL-012-MISSING-DECIDE grandfather cutoff regression. |
| [audit_ctl012_missing_decide_grandfather](/docs/generated/tests-unit-audit_ctl012_missing_decide_grandfather) | tests_by | T-2385: CTL-012-MISSING-DECIDE grandfather cutoff regression. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |

## Related

### Tasks
- T-955: Audit loop merge — combine 10 loops into 3 passes (T-860 Phase 1)

---
*Auto-generated from Component Fabric. Card: `agents-audit-completed-task-scan.yaml`*
*Last verified: 2026-04-06*
