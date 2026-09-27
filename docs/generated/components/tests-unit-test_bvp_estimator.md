# test_bvp_estimator

> Unit tests for the BVP estimator (T-1922, arc-006).

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_bvp_estimator.py`

## What It Does

Make the estimator importable. PROJECT_ROOT is the framework repo root
(this file lives at $PROJECT_ROOT/tests/unit/test_bvp_estimator.py).

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [estimator](/docs/generated/agents-termlink-bvp-estimator-estimator) | calls | BVP estimator worker implementation (T-1922, v1-heuristic, deterministic): applies a rubric-based classifier to task bodies and writes bvp_scores_proposed under M3 v2-delta semantics. |
| [write_set](/docs/generated/lib-write_set) | calls | Disjoint write-set policy validator (T-2337, arc-011 M1 §3). |
| [arc](/docs/generated/lib-arc) | calls | lib/arc.sh — Arc system (T-1653 Phase 1 / T-1661 / T-1848) |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_bvp_estimator.yaml`*
*Last verified: 2026-05-19*
