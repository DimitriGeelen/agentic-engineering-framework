# test_audit_retire_when

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_audit_retire_when.bats`

## What It Does

T-2169 — Pin audit.sh retire_when advisory. Origin: value-drivers.yaml v3
free drivers (F-RECALL, F-ORCH) carry retire_when: text describing when the
driver stops being relevant. Without an advisory rail nothing nudges the
operator. Modelled on T-1855 stale-arc precedent (WARN, never FAIL).
Rules pinned by these tests:
(a) F-RECALL recognition fires ONLY when all 4 signals are present
(b) F-ORCH recognition fires when T-1643 is completed cleanly OR G-064 closed
(c) Generic fallback emits INFO for any future free driver with retire_when
text but no dedicated recognition heuristic
(d) Inactive (commented-out) free drivers are skipped entirely

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_audit_retire_when.yaml`*
*Last verified: 2026-06-03*
