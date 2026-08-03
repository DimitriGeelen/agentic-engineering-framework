# estimator

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `agents/termlink/bvp-estimator/estimator.py`

## What It Does

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [arc](/docs/generated/lib-arc) | calls | TODO: describe what this component does |
| [write_set](/docs/generated/lib-write_set) | calls | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [bvp](/docs/generated/lib-bvp) | calls | TODO: describe what this component does |
| [bvp-estimator](/docs/generated/agents-termlink-bvp-estimator-bvp-estimator) | calls | TODO: describe what this component does |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [bvp](/docs/generated/lib-bvp) | called_by | TODO: describe what this component does |
| [test_bvp_estimator](/docs/generated/tests-unit-test_bvp_estimator) | called_by | TODO: describe what this component does |
| [test_bvp_estimator_v_alias](/docs/generated/tests-unit-test_bvp_estimator_v_alias) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `agents-termlink-bvp-estimator-estimator.yaml`*
*Last verified: 2026-05-19*
