# g066_readiness

> T-2198: G-066 closure-readiness gauge — covers READY against live repo, NOT_READY when each wiring leg is absent, and --strict exit-code semantics.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/g066_readiness.bats`

## What It Does

T-2198: G-066 closure-readiness gauge — covers READY against live repo,
NOT_READY when each wiring leg is absent, and --strict exit-code semantics.
The synthetic-repo strategy: build a tempdir with `.context/` + selectively
populated `lib/reviewer/` + `bin/fw` shims so each NOT_READY case isolates
exactly one failing condition. Avoids touching the live repo.

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [g066-readiness](/docs/generated/tools-g066-readiness) | tests | G-066 closure-readiness gauge — wiring-presence check. |
| [static_scan](/docs/generated/lib-reviewer-static_scan) | tests | Static-scan reviewer (T-1443 v1.0 → v1.5). |
| [dispatch_cli](/docs/generated/lib-reviewer-dispatch_cli) | tests | Dispatch mode for the reviewer (T-1951, G-066 prong 3). |
| [gaps](/docs/generated/lib-gaps) | tests | Gap-register closure helpers. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-g066_readiness.yaml`*
*Last verified: 2026-06-04*
