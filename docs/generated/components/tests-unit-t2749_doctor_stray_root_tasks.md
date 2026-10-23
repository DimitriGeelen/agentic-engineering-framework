# t2749_doctor_stray_root_tasks

> T-2749 — fw doctor's stray-root-marker check (Check 2c, T-1747 / G-069) warned on /.framework.yaml but not /.tasks/, although every project-root resolver accepts either marker.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t2749_doctor_stray_root_tasks.bats`

## What It Does

T-2749 — fw doctor's stray-root-marker check (Check 2c, T-1747 / G-069)
warned on /.framework.yaml but not /.tasks/, although every project-root
resolver accepts either marker. A stray /.tasks/ (an escaped T-9999 test
fixture) made reanchor_project_root return / for 37 days with doctor green.
FW_DOCTOR_STRAY_ROOT points the check at a temp dir so the real / is never
touched.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2749_doctor_stray_root_tasks.yaml`*
*Last verified: 2026-10-20*
