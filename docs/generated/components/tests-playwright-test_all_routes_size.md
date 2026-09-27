# test_all_routes_size

> Exhaustive all-routes response-SIZE guard (T-2775).

**Type:** script | **Subsystem:** tests-playwright | **Location:** `tests/playwright/test_all_routes_size.py`

## What It Does

2 MB. Chosen against measurement, not taste: after T-2775 the worst /timeline page is
513,706 bytes and the heaviest ordinary route is a few hundred KB, so 2 MB leaves ~4x
headroom for honest growth while catching anything in the runaway class (the pre-fix page
was 34x this). A cap that only just fits today's corpus would fail on corpus growth and
teach everyone to raise it, which is how a guard stops meaning anything.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [ux-review](/docs/generated/agents-ux-review-ux-review) | calls | UX-review capture engine (T-2002): drives Watchtower render surfaces in a headless browser across every appearance preset and produces visual review artifacts for human review. |

---
*Auto-generated from Component Fabric. Card: `tests-playwright-test_all_routes_size.yaml`*
*Last verified: 2026-08-03*
