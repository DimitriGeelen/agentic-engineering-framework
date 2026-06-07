# workflow_coverage

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/workflow_coverage.py`

## What It Does

T-1803: a workflow declared but not dispatched in this many days is "stale" —
a maintenance signal (consider deprecating), not a runtime failure. Surfaced
as audit WARN, not FAIL. Threshold picked as ≈ one quarter; param-injectable
for tests, no config plumbing until pressure (T-819 pattern).

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_workflow_coverage](/docs/generated/tests-unit-test_workflow_coverage) | called_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-workflow_coverage.yaml`*
*Last verified: 2026-05-12*
