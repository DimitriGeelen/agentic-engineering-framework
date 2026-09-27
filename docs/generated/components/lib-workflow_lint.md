# workflow_lint

> Workflow schema linter for `.context/project/workflows/*.yaml`.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/workflow_lint.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [resolver](/docs/generated/lib-resolver) | calls | Resolver — workflow lookup, prompt assembly, variant selection, telemetry. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [worker_kinds_parity](/docs/generated/lib-worker_kinds_parity) | called_by | T-1946 — Worker-kinds parity check helper. |
| [worker_kinds_parity](/docs/generated/lib-worker_kinds_parity) | uses_by | T-1946 — Worker-kinds parity check helper. |
| [test_doctor_scope_tags](/docs/generated/tests-unit-test_doctor_scope_tags) | called_by | T-1707 / G-065 Stream 2 — fw doctor scope tagging. |
| [test_doctor_scope_tags](/docs/generated/tests-unit-test_doctor_scope_tags) | tests_by | T-1707 / G-065 Stream 2 — fw doctor scope tagging. |
| [test_workflow_schema_pause_lint](/docs/generated/tests-unit-test_workflow_schema_pause_lint) | called_by | Tests for the workflow schema linter (lib/workflow_lint.py). |
| [t1719_ask_routing](/docs/generated/tests-unit-t1719_ask_routing) | tests_by | T-1719 A3 — `fw ask` routes through the Resolver, with a cloud fallback. |

---
*Auto-generated from Component Fabric. Card: `lib-workflow_lint.yaml`*
*Last verified: 2026-05-13*
