# bvp

> TODO: describe what this component does

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

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [estimator](/docs/generated/agents-termlink-bvp-estimator-estimator) | calls | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-bvp.yaml`*
*Last verified: 2026-05-19*
