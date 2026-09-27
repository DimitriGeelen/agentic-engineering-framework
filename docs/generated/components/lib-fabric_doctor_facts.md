# fabric_doctor_facts

> Flatten `underpopulated.py --json` into one tab-separated line for `fw doctor`.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/fabric_doctor_facts.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [cron_dry_run](/docs/generated/lib-cron_dry_run) | calls | T-1944 — Cron registry → generated dry-run helper. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [t3430_fabric_audit_doctor](/docs/generated/tests-unit-t3430_fabric_audit_doctor) | tests_by | T-3430: the audit + doctor surfaces for under-populated fabric cards. |

---
*Auto-generated from Component Fabric. Card: `lib-fabric_doctor_facts.yaml`*
*Last verified: 2026-09-22*
