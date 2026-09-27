# estimator

> BVP estimator worker implementation (T-1922, v1-heuristic, deterministic): applies a rubric-based classifier to task bodies and writes bvp_scores_proposed under M3 v2-delta semantics.

**Type:** script | **Subsystem:** framework-core | **Location:** `agents/termlink/bvp-estimator/estimator.py`

## What It Does

## Dependencies (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [arc](/docs/generated/lib-arc) | calls | lib/arc.sh — Arc system (T-1653 Phase 1 / T-1661 / T-1848) |
| [write_set](/docs/generated/lib-write_set) | calls | Disjoint write-set policy validator (T-2337, arc-011 M1 §3). |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [bvp](/docs/generated/lib-bvp) | calls | lib/bvp.sh — Business Value Points (BVP) read-only CLI |
| [bvp-estimator](/docs/generated/agents-termlink-bvp-estimator-bvp-estimator) | calls | TermLink worker entry point for the BVP estimator (T-1922): thin shell wrapper forwarding to estimator.py per the agents/<name>/<name>.sh convention. |
| [value-drivers](/docs/generated/policy-value-drivers) | calls | BVP value-driver registry (T-1918, arc-006): constitutional directives D1-D4 plus free drivers with weights, rubrics, and retire_when conditions. Drives BVP scoring, ranking, the estimator worker, and the audit retire_when advisory rail. |
| [bvp-scorability](/docs/generated/lib-bvp-scorability) | calls | lib/bvp-scorability.sh — T-3428 (OBS-463 leg 3), arc-006. |

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [bvp](/docs/generated/lib-bvp) | called_by | lib/bvp.sh — Business Value Points (BVP) read-only CLI |
| [test_bvp_estimator](/docs/generated/tests-unit-test_bvp_estimator) | called_by | Unit tests for the BVP estimator (T-1922, arc-006). |
| [test_bvp_estimator_v_alias](/docs/generated/tests-unit-test_bvp_estimator_v_alias) | tests_by | T-2343 — BVP estimator dispatch name-alias fallback. |
| [test_t3068_unknown_cost](/docs/generated/tests-unit-test_t3068_unknown_cost) | called_by | T-3068: unmeasured blast radius must not price as cheapest. |
| [test_t3428_declarative_scoring](/docs/generated/tests-unit-test_t3428_declarative_scoring) | called_by | T-3428 (OBS-463 leg 2) — a driver scores from a declarative `scoring:` spec, not only from the hardcoded handler table. |

---
*Auto-generated from Component Fabric. Card: `agents-termlink-bvp-estimator-estimator.yaml`*
*Last verified: 2026-05-19*
