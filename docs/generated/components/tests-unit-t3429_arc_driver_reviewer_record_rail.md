# t3429_arc_driver_reviewer_record_rail

> T-3429 (arc-006, D-586): the audit rail behind the default-add ruling.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3429_arc_driver_reviewer_record_rail.bats`

## What It Does

T-3429 (arc-006, D-586): the audit rail behind the default-add ruling.
Arc-scoped drivers are added on a static reviewer's word now, not an operator
click. That trade is only honest while the verdict stays on the entry — an
`approved_by: reviewer:...` row with no `reviewer:` block reads exactly like a
certified driver and carries no evidence anything was checked. Three legs:
WARN (claim without usable verdict), PASS (claim with verdict), silent (no
scoped drivers to speak about).

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3429_arc_driver_reviewer_record_rail.yaml`*
*Last verified: 2026-09-22*
