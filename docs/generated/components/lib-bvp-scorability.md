# bvp-scorability

> lib/bvp-scorability.sh — T-3428 (OBS-463 leg 3), arc-006.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/bvp-scorability.sh`

## What It Does

lib/bvp-scorability.sh — T-3428 (OBS-463 leg 3), arc-006.
One fact function for the audit and doctor rails. It answers a single
question about every ACTIVE value driver — free (policy/value-drivers.yaml)
and arc-scoped (.context/arcs/*.yaml `scoped_drivers[]`):
can the estimator score this driver at all?
A driver is SCORABLE when a hand-written handler exists for its id or name
(agents/termlink/bvp-estimator/estimator.py::_handler_table) or when it
carries a declarative `scoring:` block that validates (T-3428). Anything
else is a driver that is only a NAME: T-3427 keeps it out of the ranking
denominator, so it does not distort the ranking any more — but it also

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [estimator](/docs/generated/agents-termlink-bvp-estimator-estimator) | called_by | BVP estimator worker implementation (T-1922, v1-heuristic, deterministic): applies a rubric-based classifier to task bodies and writes bvp_scores_proposed under M3 v2-delta semantics. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [test_t3428_declarative_scoring](/docs/generated/tests-unit-test_t3428_declarative_scoring) | called_by | T-3428 (OBS-463 leg 2) — a driver scores from a declarative `scoring:` spec, not only from the hardcoded handler table. |

---
*Auto-generated from Component Fabric. Card: `lib-bvp-scorability.yaml`*
*Last verified: 2026-09-22*
