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

---
*Auto-generated from Component Fabric. Card: `tests-unit-self_vendor_parity.yaml`*
*Last verified: 2026-08-01*
