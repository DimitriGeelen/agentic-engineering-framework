# resolver

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/resolver.py`

## What It Does

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [patterns-data](/docs/generated/patterns-data) | calls | Stores failure, success, and workflow patterns discovered during project work. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [spawn](/docs/generated/lib-spawn) | calls | TODO: describe what this component does |

## Used By (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [resolver-shim](/docs/generated/lib-resolver-sh) | called_by | Thin shell shim that routes `fw resolver` invocations to lib/resolver.py. Per D-073: shim does PROJECT_ROOT export + argv passthrough only — no script-level logic. |
| [test_resolver](/docs/generated/tests-unit-test_resolver) | called_by | TODO: describe what this component does |
| [spawn](/docs/generated/lib-spawn) | called_by | TODO: describe what this component does |
| [pause_resolve](/docs/generated/lib-pause_resolve) | uses_by | TODO: describe what this component does |
| [workflow_lint](/docs/generated/lib-workflow_lint) | called_by | TODO: describe what this component does |
| [worker_kinds_parity](/docs/generated/lib-worker_kinds_parity) | called_by | TODO: describe what this component does |
| [worker_kinds_parity](/docs/generated/lib-worker_kinds_parity) | uses_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-resolver.yaml`*
*Last verified: 2026-05-03*
