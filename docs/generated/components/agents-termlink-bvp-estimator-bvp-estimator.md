# bvp-estimator

> TermLink worker entry point for the BVP estimator (T-1922): thin shell wrapper forwarding to estimator.py per the agents/<name>/<name>.sh convention.

**Type:** script | **Subsystem:** framework-core | **Location:** `agents/termlink/bvp-estimator/bvp-estimator.sh`

## What It Does

bvp-estimator.sh — TermLink worker entry point (T-1922, arc-006).
Thin shell wrapper around estimator.py so the worker fits the TermLink
agent convention (`agents/<name>/<name>.sh`). Forwards all args to the
Python implementation.
Usage:
./bvp-estimator.sh one T-XXX [--dry-run] [--json]
./bvp-estimator.sh all [--dry-run] [--limit N] [--statuses captured started-work]
./bvp-estimator.sh determinism T-XXX [--runs 3]
./bvp-estimator.sh measure-a3 [--n 20] [--output PATH]
Invoked via `fw bvp estimate` (lib/bvp.sh routing) for the common case.

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [resume](/docs/generated/agents-resume-resume) | called_by | Resume Agent - Post-compaction recovery and state synchronization |
| [update-task](/docs/generated/agents-task-create-update-task) | called_by | Task Update Agent - Status transitions with auto-triggers |
| [estimator](/docs/generated/agents-termlink-bvp-estimator-estimator) | called_by | BVP estimator worker implementation (T-1922, v1-heuristic, deterministic): applies a rubric-based classifier to task bodies and writes bvp_scores_proposed under M3 v2-delta semantics. |
| [t3051_exec_bit_gates](/docs/generated/tests-unit-t3051_exec_bit_gates) | tests_by | T-3051 — repo-tracked helper scripts must not be gated on their exec bit. |

---
*Auto-generated from Component Fabric. Card: `agents-termlink-bvp-estimator-bvp-estimator.yaml`*
*Last verified: 2026-05-19*
