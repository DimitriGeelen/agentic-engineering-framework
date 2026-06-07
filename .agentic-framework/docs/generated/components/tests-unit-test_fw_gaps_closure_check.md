# test_fw_gaps_closure_check

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_fw_gaps_closure_check.bats`

## What It Does

T-1752 — `fw gaps` honours optional closure_check_command field.
Contract:
- Gap without the field renders unchanged (backward compatible).
- Gap with a passing check (verdict=READY) renders Closure: READY (green).
- Gap with a failing/timing-out/non-JSON check renders Closure: ERROR.
- Verdict counters from JSON are surfaced when present (cron_firing_dates,
closure_threshold_dates → "have/need" tag).
Origin: T-1750 shipped tools/g064-readiness.py — a closure-readiness gauge.
T-1752 generalises so any future watching gap can declare its own check.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [g064-readiness](/docs/generated/tools-g064-readiness) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_fw_gaps_closure_check.yaml`*
*Last verified: 2026-05-05*
