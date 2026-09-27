# t3430_fabric_drift_underpopulated

> T-3430: `fw fabric drift` gains the under-populated class.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3430_fabric_drift_underpopulated.bats`

## What It Does

T-3430: `fw fabric drift` gains the under-populated class.
The class exists because the three original classes cannot see it: an
under-populated card IS registered, its file DOES exist, and its absent edges
cannot be stale. So the control that matters here is the negative one — a
fixture that is clean on every other axis and still gets flagged.
Every fixture is built in a tmp project (L-599): the live corpus moves under
the test for reasons unrelated to these rules.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3430_fabric_drift_underpopulated.yaml`*
*Last verified: 2026-09-22*
