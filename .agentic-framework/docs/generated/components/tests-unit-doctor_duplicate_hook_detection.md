# doctor_duplicate_hook_detection

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/doctor_duplicate_hook_detection.bats`

## What It Does

T-1480 — `fw doctor` surfaces the same duplicate-hook scan as T-1479's
`fw upgrade` check. Read-only diagnostic so users see the overlap on
every health check, not only when upgrading.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-doctor_duplicate_hook_detection.yaml`*
*Last verified: 2026-04-25*
