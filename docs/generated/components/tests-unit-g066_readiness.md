# g066_readiness

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/g066_readiness.bats`

## What It Does

T-2198: G-066 closure-readiness gauge — covers READY against live repo,
NOT_READY when each wiring leg is absent, and --strict exit-code semantics.
The synthetic-repo strategy: build a tempdir with `.context/` + selectively
populated `lib/reviewer/` + `bin/fw` shims so each NOT_READY case isolates
exactly one failing condition. Avoids touching the live repo.

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [g066-readiness](/docs/generated/tools-g066-readiness) | tests | TODO: describe what this component does |
| [static_scan](/docs/generated/lib-reviewer-static_scan) | tests | TODO: describe what this component does |
| [dispatch_cli](/docs/generated/lib-reviewer-dispatch_cli) | tests | TODO: describe what this component does |
| [gaps](/docs/generated/lib-gaps) | tests | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-g066_readiness.yaml`*
*Last verified: 2026-06-04*
