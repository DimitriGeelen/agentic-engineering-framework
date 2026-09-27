# test_t3068_unknown_cost

> T-3068: unmeasured blast radius must not price as cheapest.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_t3068_unknown_cost.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [estimator](/docs/generated/agents-termlink-bvp-estimator-estimator) | calls | BVP estimator worker implementation (T-1922, v1-heuristic, deterministic): applies a rubric-based classifier to task bodies and writes bvp_scores_proposed under M3 v2-delta semantics. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_t3068_unknown_cost.yaml`*
*Last verified: 2026-08-17*
