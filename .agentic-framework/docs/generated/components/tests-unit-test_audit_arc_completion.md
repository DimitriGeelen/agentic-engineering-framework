# test_audit_arc_completion

> Unit tests for fw audit --section arc-completion (T-1656, G-062 mechanism #2) — pins WARN at >=80% completion threshold for in-progress arcs, PASS below threshold, and skip behaviour for closed/empty registries.

**Type:** script | **Subsystem:** testing | **Location:** `tests/unit/test_audit_arc_completion.py`

**Tags:** `audit`, `arcs`, `g-062`, `regression`, `t-1656`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_audit_arc_completion.yaml`*
*Last verified: 2026-05-01*
