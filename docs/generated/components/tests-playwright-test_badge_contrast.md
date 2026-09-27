# test_badge_contrast

> T-1970: Pin badge contrast on /arcs surfaces against WCAG AA (4.5:1).

**Type:** script | **Subsystem:** tests-playwright | **Location:** `tests/playwright/test_badge_contrast.py`

## What It Does

Per T-1970: classes we shipped fixes for. Their contrast is pinned in
arc_detail.html + arcs_index.html. Any future edit that drops contrast
below 4.5 will fail this test.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [target](/docs/generated/tests-playwright-target) | uses | The one place the Playwright suite decides what it is talking to (T-2784). |

---
*Auto-generated from Component Fabric. Card: `tests-playwright-test_badge_contrast.yaml`*
*Last verified: 2026-05-21*
