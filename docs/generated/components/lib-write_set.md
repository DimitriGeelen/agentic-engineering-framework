# write_set

> Disjoint write-set policy validator (T-2337, arc-011 M1 §3).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/write_set.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook-threshold](/docs/generated/lib-hook-threshold) | calls | T-1631 (B-3b of T-1626) — hook-failure threshold rule. |
| [arc](/docs/generated/lib-arc) | calls | lib/arc.sh — Arc system (T-1653 Phase 1 / T-1661 / T-1848) |

## Used By (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [estimator](/docs/generated/agents-termlink-bvp-estimator-estimator) | called_by | BVP estimator worker implementation (T-1922, v1-heuristic, deterministic): applies a rubric-based classifier to task bodies and writes bvp_scores_proposed under M3 v2-delta semantics. |
| [test_bvp_estimator](/docs/generated/tests-unit-test_bvp_estimator) | called_by | Unit tests for the BVP estimator (T-1922, arc-006). |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [orchestrator-graph](/docs/generated/agents-orchestrator-orchestrator-graph) | called_by | Orchestrator-graph (arc-011 M1, T-2339): builds a write-set-overlap and dependency graph over active tasks and emits (task_id, parallel\|serial) dispatch decisions; consumes lib.write_set.compare and yield-point.sh. |
| [t3039_write_set_implicit](/docs/generated/tests-unit-t3039_write_set_implicit) | called_by | T-3039 — the implicit framework write-set, and the false green it closes. |
| [t3039_write_set_implicit](/docs/generated/tests-unit-t3039_write_set_implicit) | tests_by | T-3039 — the implicit framework write-set, and the false green it closes. |

---
*Auto-generated from Component Fabric. Card: `lib-write_set.yaml`*
*Last verified: 2026-06-11*
