# test_t5147_readiness_stale_while_refresh

> T-5147: after a review-ledger write the board serves the last known WAITING and refreshes it in the background; it never serves a stale READY, and exact callers always recompute.

**Type:** script | **Subsystem:** tests | **Location:** `tests/web/test_t5147_readiness_stale_while_refresh.py`

## What It Does

---
*Auto-generated from Component Fabric. Card: `tests-web-test_t5147_readiness_stale_while_refresh.yaml`*
*Last verified: 2026-11-15*
