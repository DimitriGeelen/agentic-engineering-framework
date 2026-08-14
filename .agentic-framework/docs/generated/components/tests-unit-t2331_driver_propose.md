# t2331_driver_propose

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2331_driver_propose.bats`

## What It Does

T-2331 (T-2330 S1): `fw bvp driver --propose` non-Sovereign verb.
Verifies the propose-queue write primitive that lands proposals into
.context/bvp-driver-proposals.jsonl as append-only rows. The Sovereign
Approve action (Watchtower /bvp/proposed → `fw bvp driver --add
--from-watchtower`) is S2's job; this slice ships the storage primitive
and bats coverage.
Covers: append behaviour, non-Sovereign under CLAUDECODE=1, race-free
append for same driver-id, rationale length validation, weight validation,
slug validation, JSON well-formedness.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2331_driver_propose.yaml`*
*Last verified: 2026-06-11*
