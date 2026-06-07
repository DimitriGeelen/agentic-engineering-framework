# test_api_fabric_source

> Playwright tests for fabric file APIs (T-1025).

**Type:** script | **Subsystem:** tests-playwright | **Location:** `tests/playwright/test_api_fabric_source.py`

**Tags:** `playwright`, `test`

## What It Does

Flask URL normalization may return 404 before handler runs

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [conftest](/docs/generated/tests-playwright-conftest) | calls | Playwright test fixtures for Watchtower (T-969) |
| [fabric](/docs/generated/web-blueprints-fabric) | calls | Flask blueprint: Fabric |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-playwright-test_api_fabric_source.yaml`*
*Last verified: 2026-04-07*
