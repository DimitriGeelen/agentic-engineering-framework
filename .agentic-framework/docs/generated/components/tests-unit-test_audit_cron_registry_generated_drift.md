# test_audit_cron_registry_generated_drift

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_audit_cron_registry_generated_drift.bats`

## What It Does

T-1943 — Pin fw audit registry → generated cron drift FAIL (audit-side
sibling to T-1942's doctor-side WARN). Origin: T-1935 — registry edited
but `fw cron generate` was never run; doctor reported "in sync" for
3+ days while the new cron entry was invisible to the OS scheduler.
T-1771 wired audit to detect generated→deployed drift as FAIL. This test
pins the registry→generated leg at the same FAIL severity, since the same
"tasks won't run" class applies.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_audit_cron_registry_generated_drift.yaml`*
*Last verified: 2026-05-19*
