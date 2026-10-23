# t3917_handover_lock

> T-3917 (G-110, RC-2 of ring20-manager's T-2248) — the budget-critical auto-handover lock can no longer disable the auto-handover forever.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3917_handover_lock.bats`

## What It Does

T-3917 (G-110, RC-2 of ring20-manager's T-2248) — the budget-critical
auto-handover lock can no longer disable the auto-handover forever.
Measured: AEF's own .handover-in-progress was stale since 2026-06-09 (content
"1"), ring20-manager's ~163 days; every critical checkpoint skipped silently.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3917_handover_lock.yaml`*
*Last verified: 2026-10-06*
