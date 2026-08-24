# dispatch_cli

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/reviewer/dispatch_cli.py`

## What It Does

Env-var sentinel that prevents recursive dispatch inside a worker session.

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [termlink_worker](/docs/generated/lib-termlink_worker) | calls | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [termlink_worker](/docs/generated/lib-termlink_worker) | uses | TODO: describe what this component does |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [g066_readiness](/docs/generated/tests-unit-g066_readiness) | tests_by | TODO: describe what this component does |
| [g066-readiness](/docs/generated/tools-g066-readiness) | called_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-reviewer-dispatch_cli.yaml`*
*Last verified: 2026-05-22*
