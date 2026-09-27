# test_health

> Playwright tests for /health endpoint (T-1008)

**Type:** script | **Subsystem:** tests-playwright | **Location:** `tests/playwright/test_health.py`

## What It Does

200 if all healthy, 503 if Ollama unreachable (still valid)

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [target](/docs/generated/tests-playwright-target) | uses | The one place the Playwright suite decides what it is talking to (T-2784). |

---
*Auto-generated from Component Fabric. Card: `tests-playwright-test_health.yaml`*
*Last verified: 2026-04-07*
