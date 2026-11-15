# t5132_ctl013_coverage

> T-5132 (832 T-764 / RA-053, operator ruling): the CTL-013 spot-check keeps a ledger and reports its own coverage.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5132_ctl013_coverage.bats`

## What It Does

T-5132 (832 T-764 / RA-053, operator ruling): the CTL-013 spot-check keeps a ledger and
reports its own coverage. A task whose re-run failed is re-checked after newer closes push it
out of the latest-3 window, until it passes; an earlier failure not re-checked is named.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5132_ctl013_coverage.yaml`*
*Last verified: 2026-11-14*
