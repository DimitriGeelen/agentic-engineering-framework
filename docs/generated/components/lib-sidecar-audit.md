# sidecar-audit

> lib/sidecar-audit.sh — arc-011 sidecar slice 8 (T-3420).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/sidecar-audit.sh`

## What It Does

lib/sidecar-audit.sh — arc-011 sidecar slice 8 (T-3420).
One fact function for the audit rail. It reads the sidecar's OWN durable
state through `fw sidecar status --json` (lib/sidecar_cli.py) and never the
hub — the same out-of-band guarantee slice 6 (T-3417) established, carried
into the cron'd audit unchanged. There is deliberately no `termlink`
invocation anywhere in this file: a hub that answers "delivered" cannot
move these numbers because nothing here asks it.
fw_sidecar_ledger_facts <project_root>
stdout : one tab-separated line
UNKNOWN<TAB>EXPIRED_UNSWEPT<TAB>STORED<TAB>DELIVERED<TAB>TOTAL<TAB>DEAD_LETTERS

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [sidecar_audit_rail](/docs/generated/tests-unit-sidecar_audit_rail) | tests_by | T-3420 — arc-011 sidecar slice 8: the audit rail over the consult ledger. |

---
*Auto-generated from Component Fabric. Card: `lib-sidecar-audit.yaml`*
*Last verified: 2026-09-22*
