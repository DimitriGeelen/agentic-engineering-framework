# test_orchestrator_status_synthetic_filter

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_orchestrator_status_synthetic_filter.bats`

## What It Does

T-1712 — fw orchestrator status: filter T-stress-* synthetic rows from
enrichment metric, headline reports real dispatches only.
Synthetic rows (task_id matching ^T-stress-) inflate the enrichment
denominator and pollute task_type/worker_kind breakdowns with "?" values
because they have no telemetry possible. The filter pins the split so the
observability metric reflects real arc-substrate signal.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_orchestrator_status_synthetic_filter.yaml`*
*Last verified: 2026-05-04*
