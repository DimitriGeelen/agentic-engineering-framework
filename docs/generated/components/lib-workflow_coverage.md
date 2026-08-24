# workflow_coverage

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/workflow_coverage.py`

## What It Does

T-1803: a workflow declared but not dispatched in this many days is "stale" —
a maintenance signal (consider deprecating), not a runtime failure. Surfaced
as audit WARN, not FAIL. Threshold picked as ≈ one quarter; param-injectable
for tests, no config plumbing until pressure (T-819 pattern).

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [spawn](/docs/generated/lib-spawn) | uses | TODO: describe what this component does |
| [resolver](/docs/generated/lib-resolver) | uses | TODO: describe what this component does |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_workflow_coverage](/docs/generated/tests-unit-test_workflow_coverage) | called_by | TODO: describe what this component does |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |

---
*Auto-generated from Component Fabric. Card: `lib-workflow_coverage.yaml`*
*Last verified: 2026-05-12*
