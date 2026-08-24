# self_vendor_parity

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/self_vendor_parity.bats`

## What It Does

T-2711: the self-vendor PRODUCER and the audit GATE must cover the same files.
agents/audit/audit.sh check_self_vendor_drift scans
.agentic-framework/{bin,lib,agents,web} for *.sh, *.py, fw, claude-fw, *.md and
blocks the push on any mismatch. Four helpers in lib/upgrade.sh are supposed to
be able to clear it. Three of them (_self_vendor_libs/_agents/_web) ENUMERATE
their tree. _self_vendor_shim NAMED two files — `for _shim in fw claude-fw`.
So bin/hook-enable.sh, bin/integrate-go-live.sh, bin/watchtower.sh and
bin/migrate-horizon-null-completed.sh were gated by the audit and synced by
nobody: `fw vendor self` said success, `--check` said in-sync, the push gate
still refused, and its remediation line pointed at the verb that could not fix it.

## Dependencies (9)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [upgrade](/docs/generated/lib-upgrade) | calls | fw upgrade - Sync framework improvements to a consumer project |
| [hook-enable](/docs/generated/bin-hook-enable) | calls | Register framework hooks in .claude/settings.json idempotently — adds { type "command", command ".agentic-framework/bin/fw hook <name>" } entries under specified event/matcher pair. Built under T-1189 to repair T-977 false-complete (G-015). |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | tests | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [upgrade](/docs/generated/lib-upgrade) | tests | fw upgrade - Sync framework improvements to a consumer project |
| [hook-enable](/docs/generated/bin-hook-enable) | tests | Register framework hooks in .claude/settings.json idempotently — adds { type "command", command ".agentic-framework/bin/fw hook <name>" } entries under specified event/matcher pair. Built under T-1189 to repair T-977 false-complete (G-015). |
| [integrate-go-live](/docs/generated/bin-integrate-go-live) | tests | TODO: describe what this component does |
| [watchtower](/docs/generated/bin-watchtower) | tests | Launcher script for Watchtower web dashboard. Starts Flask app on configured port with optional debug mode. |
| [migrate-horizon-null-completed](/docs/generated/bin-migrate-horizon-null-completed) | tests | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-self_vendor_parity.yaml`*
*Last verified: 2026-08-01*
