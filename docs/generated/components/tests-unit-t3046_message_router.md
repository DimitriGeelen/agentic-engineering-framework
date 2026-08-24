# t3046_message_router

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3046_message_router.bats`

## What It Does

T-3046 — static msg_type router for recovered hub messages (slice 1 of T-3044).
Every test here asserts that the FAILING state actually fails, not merely that
the passing state passes. This session found three separate checks that were
green because they asserted less than their name implied (write-set `disjoint`,
a reachable-but-dead embed endpoint, an empty Verification block), so a guard
that has never been observed red is not treated as a guard.

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [message_router](/docs/generated/lib-message_router) | calls | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [message_router](/docs/generated/lib-message_router) | tests | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3046_message_router.yaml`*
*Last verified: 2026-08-16*
