# t4478_bvp_confirm_telemetry

> T-4478: `fw bvp confirm` appends one row per confirmation to an append-only NDJSON ledger (adapted from 010-termlink T-3176, proposal 348).

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4478_bvp_confirm_telemetry.bats`

## What It Does

T-4478: `fw bvp confirm` appends one row per confirmation to an append-only NDJSON
ledger (adapted from 010-termlink T-3176, proposal 348). The proposal is cleared on
confirm (M3), so without this row the estimator-guess vs confirmed pair is lost.
Every test points FW_BVP_TELEMETRY_PATH into the temp dir: the real ledger is
append-only and a fixture row written into it could never be removed.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4478_bvp_confirm_telemetry.yaml`*
*Last verified: 2026-10-20*
