# g066-readiness

> G-066 closure-readiness gauge — wiring-presence check.

**Type:** script | **Subsystem:** framework-core | **Location:** `tools/g066-readiness.py`

## What It Does

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [static_scan](/docs/generated/lib-reviewer-static_scan) | calls | Static-scan reviewer (T-1443 v1.0 → v1.5). |
| [dispatch_cli](/docs/generated/lib-reviewer-dispatch_cli) | calls | Dispatch mode for the reviewer (T-1951, G-066 prong 3). |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [g066_readiness](/docs/generated/tests-unit-g066_readiness) | tests_by | T-2198: G-066 closure-readiness gauge — covers READY against live repo, NOT_READY when each wiring leg is absent, and --strict exit-code semantics. |

---
*Auto-generated from Component Fabric. Card: `tools-g066-readiness.yaml`*
*Last verified: 2026-06-04*
