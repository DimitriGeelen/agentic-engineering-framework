# bvp

> lib/bvp.sh — Business Value Points (BVP) read-only CLI

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/bvp.sh`

## What It Does

lib/bvp.sh — Business Value Points (BVP) read-only CLI
T-1919 (arc-006, value-prioritisation). T-NEW-4. Read-only verbs:
fw bvp                       — rank all tasks by BVP desc
fw bvp T-<id>                — per-driver detail for one task
fw bvp arcs                  — rank arcs by global-driver BVP
fw bvp --quadrant {hv-lc,hv-hc,lv-lc,lv-hc}
— filter ranking by quadrant
fw bvp --help                — usage
Source-of-truth files:
policy/value-drivers.yaml     — driver weights (T-1917)

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [estimator](/docs/generated/agents-termlink-bvp-estimator-estimator) | calls | BVP estimator worker implementation (T-1922, v1-heuristic, deterministic): applies a rubric-based classifier to task bodies and writes bvp_scores_proposed under M3 v2-delta semantics. |
| [notify](/docs/generated/lib-notify) | calls | Push notification wrapper — fw_notify() function sends alerts via skills-manager alert dispatcher. Fire-and-forget, opt-in via .context/notify-config.yaml. Used by check-tier0.sh, update-task.sh, audit.sh. |

## Used By (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [resolver](/docs/generated/lib-resolver) | called_by | Resolver — workflow lookup, prompt assembly, variant selection, telemetry. |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [estimator](/docs/generated/agents-termlink-bvp-estimator-estimator) | called_by | BVP estimator worker implementation (T-1922, v1-heuristic, deterministic): applies a rubric-based classifier to task bodies and writes bvp_scores_proposed under M3 v2-delta semantics. |
| [bvp](/docs/generated/web-blueprints-bvp) | called_by | BVP scatter blueprint — T-1928 (arc-006, value-prioritisation, T-NEW-12a). |
| [bvp-help-parity](/docs/generated/tests-lint-bvp-help-parity) | tests_by | T-3069: the bvp verb surface and its documentation must agree. |
| [test_t3427_unscored_driver](/docs/generated/tests-unit-test_t3427_unscored_driver) | called_by | T-3427 (OBS-463) — a free driver with no scorer is UNSCORED, and the add verb says so before the Sovereign spends the slot. |
| [test_t3428_declarative_scoring](/docs/generated/tests-unit-test_t3428_declarative_scoring) | called_by | T-3428 (OBS-463 leg 2) — a driver scores from a declarative `scoring:` spec, not only from the hardcoded handler table. |

---
*Auto-generated from Component Fabric. Card: `lib-bvp.yaml`*
*Last verified: 2026-05-19*
