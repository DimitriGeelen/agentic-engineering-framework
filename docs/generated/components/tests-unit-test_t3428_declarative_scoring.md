# test_t3428_declarative_scoring

> T-3428 (OBS-463 leg 2) — a driver scores from a declarative `scoring:` spec, not only from the hardcoded handler table.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_t3428_declarative_scoring.py`

## What It Does

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [bvp](/docs/generated/lib-bvp) | calls | lib/bvp.sh — Business Value Points (BVP) read-only CLI |
| [bvp-scorability](/docs/generated/lib-bvp-scorability) | calls | lib/bvp-scorability.sh — T-3428 (OBS-463 leg 3), arc-006. |
| [estimator](/docs/generated/agents-termlink-bvp-estimator-estimator) | calls | BVP estimator worker implementation (T-1922, v1-heuristic, deterministic): applies a rubric-based classifier to task bodies and writes bvp_scores_proposed under M3 v2-delta semantics. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_t3428_declarative_scoring.yaml`*
*Last verified: 2026-09-22*
