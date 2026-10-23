# t3778_doctor_test_cost

> T-3778: doctor-calling bats files must not pay a whole `fw doctor` per test.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3778_doctor_test_cost.bats`

## What It Does

T-3778: doctor-calling bats files must not pay a whole `fw doctor` per test.
One doctor run costs ~50 s on a quiet host and 270-600 s under the unit-suite
pool (measured at load 170: full 10m09s, --quick 4m31s). Files that ran it once
per test crossed the 900 s per-file cap: doctor_designer_pin_drift.bats (5 runs,
900 s), t2243_doctor_self_vendor_templates.bats (4 runs, 848 s) and
test_doctor_scope_tags.bats (4 runs, 757 s) on the 2026-10-21 nightly. The two
drift checks now live in lib/doctor-drift.sh so the tests call them directly;
scope_tags shares one run via setup_file.
T-3801 extended it to t2290_doctor_mcp_content_check.bats (558 s) and
t3119_designer_currency.bats (546 s): the MCP manifest and designer-currency

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3778_doctor_test_cost.yaml`*
*Last verified: 2026-10-21*
