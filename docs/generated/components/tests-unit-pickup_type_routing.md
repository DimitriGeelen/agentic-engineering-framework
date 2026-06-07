# pickup_type_routing

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/pickup_type_routing.bats`

## What It Does

Unit tests for T-1465 — pickup envelope type → task workflow_type routing.
Constrained Option A (T-1455 GO):
bug-report       → build
feature-proposal → inception
learning         → inception
pattern          → inception
Strategy: stub `fw` on PATH to capture --type, source lib/pickup.sh, and
call pickup_create_inception with crafted envelopes. We assert on the
captured arguments — no real task is created.

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [pickup](/docs/generated/lib-pickup) | calls | Cross-project pickup pipeline that validates, deduplicates, and processes incoming YAML envelopes into inception tasks |
| [pickup](/docs/generated/lib-pickup) | tests | Cross-project pickup pipeline that validates, deduplicates, and processes incoming YAML envelopes into inception tasks |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-pickup_type_routing.yaml`*
*Last verified: 2026-04-25*
