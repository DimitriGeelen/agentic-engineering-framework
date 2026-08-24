# active-task-scan

> Single-pass scan of active task files that checks compliance, quality, research artifacts, ownership, and review queue status in one efficient pass

**Type:** script | **Subsystem:** audit | **Location:** `agents/audit/active-task-scan.py`

## What It Does

T-3061: the unclosed-but-satisfied rule lives in lib/task_satisfaction.py — the
one definition, and the one with tests (tests/unit/test_task_satisfaction.py).
`parents[2]` is the framework root in both layouts: agents/audit/x.py in the
framework repo, and .agentic-framework/agents/audit/x.py in a vendored consumer.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [task-audit](/docs/generated/lib-task-audit) | calls | Scans task files for literal placeholder content that should have been replaced during authoring, blocking review and inception decisions until resolved |

## Used By (9)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [audit_scan](/docs/generated/tests-unit-audit_scan) | called_by | TODO: describe what this component does |
| [audit_scan](/docs/generated/tests-unit-audit_scan) | tests_by | TODO: describe what this component does |
| [audit_ctl028_completed_status_consistency](/docs/generated/tests-unit-audit_ctl028_completed_status_consistency) | called_by | TODO: describe what this component does |
| [audit_ctl028_completed_status_consistency](/docs/generated/tests-unit-audit_ctl028_completed_status_consistency) | tests_by | TODO: describe what this component does |
| [audit_ctl030_completed_horizon_drift](/docs/generated/tests-unit-audit_ctl030_completed_horizon_drift) | called_by | TODO: describe what this component does |
| [audit_ctl030_completed_horizon_drift](/docs/generated/tests-unit-audit_ctl030_completed_horizon_drift) | tests_by | TODO: describe what this component does |
| [t3073_c001_recommendation_bearing_inceptions](/docs/generated/tests-unit-t3073_c001_recommendation_bearing_inceptions) | called_by | TODO: describe what this component does |
| [t3073_c001_recommendation_bearing_inceptions](/docs/generated/tests-unit-t3073_c001_recommendation_bearing_inceptions) | tests_by | TODO: describe what this component does |

## Related

### Tasks
- T-955: Audit loop merge — combine 10 loops into 3 passes (T-860 Phase 1)
- T-956: Audit Loop 2 noise fix — recalibrate quality thresholds or escalate differently (T-860 Phase 2)

---
*Auto-generated from Component Fabric. Card: `agents-audit-active-task-scan.yaml`*
*Last verified: 2026-04-06*
