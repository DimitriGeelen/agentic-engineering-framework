# t3430_fabric_audit_doctor

> T-3430: the audit + doctor surfaces for under-populated fabric cards.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3430_fabric_audit_doctor.bats`

## What It Does

T-3430: the audit + doctor surfaces for under-populated fabric cards.
Both are mirrors of the same scan, so both legs are tested against the same
two fixtures — a dirty corpus (must WARN, must name the counts) and a clean
one (must PASS at zero). The clean leg is the one that matters: a check that
can only ever WARN is indistinguishable from a check that is always on.
The audit function is exercised through lib/fabric_doctor_facts.py + the
scanner rather than by booting audit.sh, which takes the shared audit lock
and several minutes; the integration of the two is pinned by the live
Verification line on the task instead.

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fabric_doctor_facts](/docs/generated/lib-fabric_doctor_facts) | tests | Flatten `underpopulated.py --json` into one tab-separated line for `fw doctor`. |
| [underpopulated](/docs/generated/agents-fabric-lib-underpopulated) | tests | Scan component cards for the under-populated class — a card that says nothing. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | tests | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3430_fabric_audit_doctor.yaml`*
*Last verified: 2026-09-22*
