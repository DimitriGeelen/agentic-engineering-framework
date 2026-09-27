# test_cockpit_activity_navigation

> T-2113: cockpit Recent Activity task-link click must NOT bounce back.

**Type:** script | **Subsystem:** tests-playwright | **Location:** `tests/playwright/test_cockpit_activity_navigation.py`

## What It Does

The polling fragment loads via hx-trigger="load, every 15s". Wait a bit
extra so the load-triggered fetch completes after networkidle settles.

---
*Auto-generated from Component Fabric. Card: `tests-playwright-test_cockpit_activity_navigation.yaml`*
*Last verified: 2026-05-30*
