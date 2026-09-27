# t3429_arc_approve_driver_default_path

> T-3429 (arc-006, D-586): approve-driver's default path is the reviewer.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3429_arc_approve_driver_default_path.bats`

## What It Does

T-3429 (arc-006, D-586): approve-driver's default path is the reviewer.
The operator ruling moved WHO certifies an arc-scoped driver, not WHAT the
structural limits are — so these tests pin both halves: the new reviewer gate
AND that cap-3 / weight<=6 / T-1979 dedup / the §ACD gate on --none all still
bite on the path that no longer asks a human.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3429_arc_approve_driver_default_path.yaml`*
*Last verified: 2026-09-22*
