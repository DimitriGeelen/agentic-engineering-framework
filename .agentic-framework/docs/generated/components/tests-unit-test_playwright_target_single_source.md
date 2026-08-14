# test_playwright_target_single_source

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_playwright_target_single_source.py`

## What It Does

A bare host:port literal. Matches "http://localhost:3099", "127.0.0.1:5000" and friends.
Deliberately not anchored to 3099 — the defect is hard-coding *an* address, not that
particular one, and a guard that only knows today's number teaches people to pick a
different one.

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_playwright_target_single_source.yaml`*
*Last verified: 2026-08-04*
