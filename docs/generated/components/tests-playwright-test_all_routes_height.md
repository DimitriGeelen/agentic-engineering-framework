# test_all_routes_height

> Exhaustive all-routes height guard (T-2048).

**Type:** script | **Subsystem:** tests-playwright | **Location:** `tests/playwright/test_all_routes_height.py`

## What It Does

Mirror agents/ux-review/ux-review.py TALL_PAGE_CAP_PX — the guard and the detector
must stay in lockstep. (Asserted by test_height_cap_matches_detector below.)

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [ux-review](/docs/generated/agents-ux-review-ux-review) | calls | UX-review capture engine (T-2002): drives Watchtower render surfaces in a headless browser across every appearance preset and produces visual review artifacts for human review. |

---
*Auto-generated from Component Fabric. Card: `tests-playwright-test_all_routes_height.yaml`*
*Last verified: 2026-05-25*
