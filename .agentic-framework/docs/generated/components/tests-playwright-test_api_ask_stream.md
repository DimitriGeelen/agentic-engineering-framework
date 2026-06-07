# test_api_ask_stream

> Playwright tests for /ask/stream SSE endpoint (T-1041).

**Type:** script | **Subsystem:** tests-playwright | **Location:** `tests/playwright/test_api_ask_stream.py`

**Tags:** `playwright`, `test`

## What It Does

Should return 400 for missing query or SSE with error event

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [conftest](/docs/generated/tests-playwright-conftest) | calls | Playwright test fixtures for Watchtower (T-969) |
| [api](/docs/generated/web-blueprints-api) | calls | Watchtower API blueprint: JSON endpoints for AJAX/htmx — task data, metrics, approval actions. |

---
*Auto-generated from Component Fabric. Card: `tests-playwright-test_api_ask_stream.yaml`*
*Last verified: 2026-04-07*
