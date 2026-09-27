# test_approvals_height

> Playwright regression test for /approvals rendered height (T-2038).

**Type:** script | **Subsystem:** tests-playwright | **Location:** `tests/playwright/test_approvals_height.py`

## What It Does

Mirror agents/ux-review/ux-review.py TALL_PAGE_CAP_PX — above this a full_page
screenshot can wedge the browser, so the page must render below it.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [ux-review](/docs/generated/agents-ux-review-ux-review) | calls | UX-review capture engine (T-2002): drives Watchtower render surfaces in a headless browser across every appearance preset and produces visual review artifacts for human review. |

---
*Auto-generated from Component Fabric. Card: `tests-playwright-test_approvals_height.yaml`*
*Last verified: 2026-05-25*
