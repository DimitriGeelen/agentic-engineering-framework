# t4951_readiness_missing_policy_test

> T-4951: with no policy/value-drivers.yaml, bvp.load_policy() calls sys.exit(2). A SystemExit escaped /approvals' `except Exception` degrade-to-ratio path and aborted the Arc Closure build.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4951_readiness_missing_policy_test.py`

## What It Does

The /approvals caller's shape: `except Exception: return None` must now see it.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4951_readiness_missing_policy_test.yaml`*
*Last verified: 2026-11-01*
