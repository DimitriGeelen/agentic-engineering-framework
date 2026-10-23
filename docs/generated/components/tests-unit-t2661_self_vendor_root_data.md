# t2661_self_vendor_root_data

> T-2661: do_vendor ships four ROOT single files (.secret-scan-patterns, .secret-scan-allowlist, status-transitions.yaml, metrics.sh) but no _self_vendor_* class synced or checked them, and the audit's drift scan did not look at them.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t2661_self_vendor_root_data.bats`

## What It Does

T-2661: do_vendor ships four ROOT single files (.secret-scan-patterns,
.secret-scan-allowlist, status-transitions.yaml, metrics.sh) but no
_self_vendor_* class synced or checked them, and the audit's drift scan did not
look at them. Field state at filing: .agentic-framework/.secret-scan-allowlist
666 bytes behind its source while `fw vendor self --check` said in-sync.
t1  helper syncs a changed and a missing root data file
t2  helper dry-run says "would sync N root data" and mutates nothing
t3  consumer-safe: no .agentic-framework/ → no-op
t4  --check in a clean clone goes red on planted .secret-scan-allowlist drift
t5  audit drift scan names every file in the helper's list (parity)

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2661_self_vendor_root_data.yaml`*
*Last verified: 2026-10-21*
