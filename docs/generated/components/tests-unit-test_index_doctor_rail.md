# test_index_doctor_rail

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_index_doctor_rail.bats`

## What It Does

The doctor/audit rail over the vector index — T-3013 (T-3005 slice 4).
Every verdict here is asserted against a fixture that produces a DIFFERENT
verdict from the same code. A check verified only in the state it normally
reports is not verified — this arc has already shipped four instruments that
were green because they could not be anything else (T-3004), and two more
caught mid-build in T-3011.
So: stale is proven against fresh, fresh against stale, unknown against both.

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_index_doctor_rail.yaml`*
*Last verified: 2026-08-15*
