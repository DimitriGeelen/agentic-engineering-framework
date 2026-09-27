# value-drivers

> BVP value-driver registry (T-1918, arc-006): constitutional directives D1-D4 plus free drivers with weights, rubrics, and retire_when conditions. Drives BVP scoring, ranking, the estimator worker, and the audit retire_when advisory rail.

**Type:** config | **Subsystem:** governance | **Location:** `policy/value-drivers.yaml`

**Tags:** `policy`, `bvp`, `arc-006`

## What It Does

policy/value-drivers.yaml
Business Value Point (BVP) drivers for AEF task & arc prioritisation.
Two layers:
- protected drivers (D1-D4) == the Constitutional Directives. Fixed meaning,
mutable weight, NEVER removable. They are the chassis.
- free drivers          == temporary, focus-setting axes. Add/drop deliberately.
They are the steering wheel: you add one BECAUSE it is the focus this period,
and retire it once the focus passes. Cap of 5 free (9 total); add-one-drop-one
when full. The cap is a forcing function for focus, not a budget to ration.
Distinction that earns a free driver its slot:

## Used By (10)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [bvp](/docs/generated/lib-bvp) | reads | lib/bvp.sh — Business Value Points (BVP) read-only CLI |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | reads | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [estimator](/docs/generated/agents-termlink-bvp-estimator-estimator) | reads | BVP estimator worker implementation (T-1922, v1-heuristic, deterministic): applies a rubric-based classifier to task bodies and writes bvp_scores_proposed under M3 v2-delta semantics. |
| [bvp](/docs/generated/web-blueprints-bvp) | reads | BVP scatter blueprint — T-1928 (arc-006, value-prioritisation, T-NEW-12a). |
| [resolver](/docs/generated/lib-resolver) | reads | Resolver — workflow lookup, prompt assembly, variant selection, telemetry. |
| [init](/docs/generated/lib-init) | writes | fw init - Bootstrap a new project with the Agentic Engineering Framework |
| [upgrade](/docs/generated/lib-upgrade) | writes | fw upgrade - Sync framework improvements to a consumer project |
| [estimator](/docs/generated/agents-termlink-bvp-estimator-estimator) | called_by | BVP estimator worker implementation (T-1922, v1-heuristic, deterministic): applies a rubric-based classifier to task bodies and writes bvp_scores_proposed under M3 v2-delta semantics. |
| [resolver](/docs/generated/lib-resolver) | called_by | Resolver — workflow lookup, prompt assembly, variant selection, telemetry. |
| [bvp](/docs/generated/web-blueprints-bvp) | called_by | BVP scatter blueprint — T-1928 (arc-006, value-prioritisation, T-NEW-12a). |

---
*Auto-generated from Component Fabric. Card: `policy-value-drivers.yaml`*
*Last verified: 2026-09-08*
