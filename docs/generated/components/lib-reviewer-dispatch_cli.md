# dispatch_cli

> Dispatch mode for the reviewer (T-1951, G-066 prong 3).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/reviewer/dispatch_cli.py`

## What It Does

Env-var sentinel that prevents recursive dispatch inside a worker session.

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [termlink_worker](/docs/generated/lib-termlink_worker) | calls | TermLinkWorker — subprocess wrapper for `fw termlink dispatch`. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [termlink_worker](/docs/generated/lib-termlink_worker) | uses | TermLinkWorker — subprocess wrapper for `fw termlink dispatch`. |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [g066_readiness](/docs/generated/tests-unit-g066_readiness) | tests_by | T-2198: G-066 closure-readiness gauge — covers READY against live repo, NOT_READY when each wiring leg is absent, and --strict exit-code semantics. |
| [g066-readiness](/docs/generated/tools-g066-readiness) | called_by | G-066 closure-readiness gauge — wiring-presence check. |

---
*Auto-generated from Component Fabric. Card: `lib-reviewer-dispatch_cli.yaml`*
*Last verified: 2026-05-22*
