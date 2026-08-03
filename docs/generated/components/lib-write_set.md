# write_set

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/write_set.py`

## What It Does

Walk up from CWD looking for .tasks/ — the canonical project marker

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [estimator](/docs/generated/agents-termlink-bvp-estimator-estimator) | called_by | TODO: describe what this component does |
| [test_bvp_estimator](/docs/generated/tests-unit-test_bvp_estimator) | called_by | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [orchestrator-graph](/docs/generated/agents-orchestrator-orchestrator-graph) | called_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-write_set.yaml`*
*Last verified: 2026-06-11*
