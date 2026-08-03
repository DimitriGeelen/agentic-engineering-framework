# arc_create_start_flag

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/arc_create_start_flag.bats`

## What It Does

T-1852 counter-proposal: `fw arc create --start` one-step convenience.
Default behaviour writes `status: draft`; --start writes `status: in-progress`.
Preserves backwards-compat for "create + immediately work" muscle memory
while keeping the draft state reachable as the default.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-arc_create_start_flag.yaml`*
*Last verified: 2026-05-18*
