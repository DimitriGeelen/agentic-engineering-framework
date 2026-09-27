# worker_kinds_parity

> T-1946 — Worker-kinds parity check helper.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/worker_kinds_parity.py`

## What It Does

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [resolver](/docs/generated/lib-resolver) | calls | Resolver — workflow lookup, prompt assembly, variant selection, telemetry. |
| [workflow_lint](/docs/generated/lib-workflow_lint) | calls | Workflow schema linter for `.context/project/workflows/*.yaml`. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [resolver](/docs/generated/lib-resolver) | uses | Resolver — workflow lookup, prompt assembly, variant selection, telemetry. |
| [workflow_lint](/docs/generated/lib-workflow_lint) | uses | Workflow schema linter for `.context/project/workflows/*.yaml`. |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [t1719_ask_routing](/docs/generated/tests-unit-t1719_ask_routing) | tests_by | T-1719 A3 — `fw ask` routes through the Resolver, with a cloud fallback. |

---
*Auto-generated from Component Fabric. Card: `lib-worker_kinds_parity.yaml`*
*Last verified: 2026-05-20*
