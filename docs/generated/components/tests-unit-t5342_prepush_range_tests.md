# t5342_prepush_range_tests

> T-5342 (G-138): at pre-push, run the unit test files the pushed range touches.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5342_prepush_range_tests.bats`

## What It Does

T-5342 (G-138): at pre-push, run the unit test files the pushed range touches.
Hermetic: each test builds a throwaway git project with its own tests/unit,
a hand-written nightly report and baseline, and runs the audit's two pre-push
checks (check_prepush_range_tests, then check_unit_suite_report) against it.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5342_prepush_range_tests.yaml`*
*Last verified: 2026-11-21*
