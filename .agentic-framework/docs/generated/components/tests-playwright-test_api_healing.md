# test_api_healing

> Playwright tests for /api/healing/<task_id> endpoint (T-1026).

**Type:** script | **Subsystem:** tests-playwright | **Location:** `tests/playwright/test_api_healing.py`

**Tags:** `playwright`, `test`

## What It Does

The endpoint runs fw healing diagnose and returns 200 with output
regardless of whether the task exists (diagnosis output shows the error)

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [conftest](/docs/generated/tests-playwright-conftest) | calls | Playwright test fixtures for Watchtower (T-969) |
| [session](/docs/generated/web-blueprints-session) | calls | Flask blueprint: Session |

---
*Auto-generated from Component Fabric. Card: `tests-playwright-test_api_healing.yaml`*
*Last verified: 2026-04-07*
