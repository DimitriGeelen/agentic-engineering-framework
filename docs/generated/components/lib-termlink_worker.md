# termlink_worker

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/termlink_worker.py`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_termlink_worker](/docs/generated/tests-unit-test_termlink_worker) | called_by | TODO: describe what this component does |
| [dispatch_cli](/docs/generated/lib-reviewer-dispatch_cli) | called_by | TODO: describe what this component does |
| [ollama_loop](/docs/generated/lib-ollama_loop) | called_by | TODO: describe what this component does |
| [dispatch_cli](/docs/generated/lib-reviewer-dispatch_cli) | uses_by | TODO: describe what this component does |
| [spawn](/docs/generated/lib-spawn) | uses_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-termlink_worker.yaml`*
*Last verified: 2026-05-12*
