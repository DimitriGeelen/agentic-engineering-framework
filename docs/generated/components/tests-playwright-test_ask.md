# test_ask

> Playwright tests for /api/v1/ask endpoint (T-1025).

**Type:** script | **Subsystem:** tests-playwright | **Location:** `tests/playwright/test_ask.py`

**Tags:** `playwright`, `test`

## What It Does

200 if LLM available, 500/503 if not configured — all return valid JSON

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [conftest](/docs/generated/tests-playwright-conftest) | calls | Playwright test fixtures for Watchtower (T-969) |
| [api](/docs/generated/web-blueprints-api) | calls | Watchtower API blueprint: JSON endpoints for AJAX/htmx — task data, metrics, approval actions. |

---
*Auto-generated from Component Fabric. Card: `tests-playwright-test_ask.yaml`*
*Last verified: 2026-04-07*
