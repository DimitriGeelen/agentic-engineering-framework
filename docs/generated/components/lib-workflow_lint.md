# workflow_lint

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/workflow_lint.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [resolver](/docs/generated/lib-resolver) | calls | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [worker_kinds_parity](/docs/generated/lib-worker_kinds_parity) | called_by | TODO: describe what this component does |
| [worker_kinds_parity](/docs/generated/lib-worker_kinds_parity) | uses_by | TODO: describe what this component does |
| [test_doctor_scope_tags](/docs/generated/tests-unit-test_doctor_scope_tags) | called_by | TODO: describe what this component does |
| [test_doctor_scope_tags](/docs/generated/tests-unit-test_doctor_scope_tags) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-workflow_lint.yaml`*
*Last verified: 2026-05-13*
