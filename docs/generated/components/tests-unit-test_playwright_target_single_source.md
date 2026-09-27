# test_playwright_target_single_source

> Playwright tests must take their target from one place (T-2784).

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_playwright_target_single_source.py`

## What It Does

A bare host:port literal. Matches "http://localhost:3099", "127.0.0.1:5000" and friends.
Deliberately not anchored to 3099 — the defect is hard-coding *an* address, not that
particular one, and a guard that only knows today's number teaches people to pick a
different one.

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_playwright_target_single_source.yaml`*
*Last verified: 2026-08-04*
