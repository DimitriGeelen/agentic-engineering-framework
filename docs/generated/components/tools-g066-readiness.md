# g066-readiness

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tools/g066-readiness.py`

## What It Does

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [static_scan](/docs/generated/lib-reviewer-static_scan) | calls | TODO: describe what this component does |
| [dispatch_cli](/docs/generated/lib-reviewer-dispatch_cli) | calls | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [g066_readiness](/docs/generated/tests-unit-g066_readiness) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tools-g066-readiness.yaml`*
*Last verified: 2026-06-04*
