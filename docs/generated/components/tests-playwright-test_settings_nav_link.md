# test_settings_nav_link

> Playwright guard for T-2032 — the settings gear is visible and navigates to the page.

**Type:** script | **Subsystem:** tests-playwright | **Location:** `tests/playwright/test_settings_nav_link.py`

## What It Does

The body is hx-boost="true" — nav is an AJAX swap + history push, not a full
page load — so wait for the URL to change rather than for domcontentloaded.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [target](/docs/generated/tests-playwright-target) | uses | The one place the Playwright suite decides what it is talking to (T-2784). |

---
*Auto-generated from Component Fabric. Card: `tests-playwright-test_settings_nav_link.yaml`*
*Last verified: 2026-05-24*
