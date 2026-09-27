# test_arcs_detail_arc_id_membership

> T-1876 (T-NEW-12): /arcs/<slug> reads arc_id frontmatter for constituents.

**Type:** script | **Subsystem:** tests-playwright | **Location:** `tests/playwright/test_arcs_detail_arc_id_membership.py`

## What It Does

All known arc-grooming arc tasks at the time of this test's authoring.
Tests assert ≥10 of these appear; new tasks added to the arc after writing
this test will not break it (lower bound check).

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [arc](/docs/generated/lib-arc) | calls | lib/arc.sh — Arc system (T-1653 Phase 1 / T-1661 / T-1848) |

---
*Auto-generated from Component Fabric. Card: `tests-playwright-test_arcs_detail_arc_id_membership.yaml`*
*Last verified: 2026-05-17*
