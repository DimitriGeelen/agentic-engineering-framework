# t3450_push_timeout_derivation

> T-3450 — the handover push timeout is derived from the measured audit gate cost, instead of a static 300.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3450_push_timeout_derivation.bats`

## What It Does

T-3450 — the handover push timeout is derived from the measured audit
gate cost, instead of a static 300.
Sibling to tests/unit/t3421_prepush_lock_wait.bats: fw_handover_push_timeout_default
(lib/prepush-lock-wait.sh) reuses that function's extracted ledger reader
(fw_audit_timing_read_structure_seconds) so both derivations parse
.context/audits/full-audit-timing.yaml in exactly one place. Hermetic:
every ledger here is a fixture under a tmpdir.
NOTE on filename: T-3450's own task file and a stale comment in
handover.sh (predating this task) both refer to
"tests/unit/t3062_push_timeout_budget.bats" as the file that pins this

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3450_push_timeout_derivation.yaml`*
*Last verified: 2026-09-24*
