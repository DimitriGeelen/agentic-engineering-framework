# worker_kinds_parity

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/worker_kinds_parity.py`

## What It Does

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [resolver](/docs/generated/lib-resolver) | calls | TODO: describe what this component does |
| [workflow_lint](/docs/generated/lib-workflow_lint) | calls | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [resolver](/docs/generated/lib-resolver) | uses | TODO: describe what this component does |
| [workflow_lint](/docs/generated/lib-workflow_lint) | uses | TODO: describe what this component does |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [t1719_ask_routing](/docs/generated/tests-unit-t1719_ask_routing) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-worker_kinds_parity.yaml`*
*Last verified: 2026-05-20*
