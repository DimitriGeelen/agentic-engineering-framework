# doctor-drift

> lib/doctor-drift.sh — T-3778

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/doctor-drift.sh`

## What It Does

lib/doctor-drift.sh — T-3778
Two `fw doctor` content-drift checks, lifted out of do_doctor so they can be
called on their own. Doctor sources this file and calls both functions in the
same place the inline blocks used to sit; the output is unchanged.
Why they live here: the bats files that cover these checks used to run a whole
`bin/fw doctor` per test (~50 s quiet, 180-600 s under the unit-suite pool) to
assert on one line, and doctor_designer_pin_drift.bats (5 tests) /
t2243_doctor_self_vendor_templates.bats (4 tests) kept crossing the 900 s
per-file cap. Callable functions let each file keep ONE full-doctor wiring
test and exercise every state directly.

---
*Auto-generated from Component Fabric. Card: `lib-doctor-drift.yaml`*
*Last verified: 2026-10-21*
