# test_mirror_stderr_capture

> T-1843 / T-1829 — lib/mirror.sh stderr capture on push-failed.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_mirror_stderr_capture.bats`

## What It Does

T-1843 / T-1829 — lib/mirror.sh stderr capture on push-failed.
Origin: T-1828 RCA — the OneDev→GitHub mirror failed every 15min for 7+
hours with only "push-failed" in .context/working/.mirror-sync.log. Took
a consumer pickup to surface the actual blocking error (T-1603 hook).
This test pins that mirror_sync_one captures push stderr into the log on
failure so the next stall is diagnosable from logs alone.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [mirror](/docs/generated/lib-mirror) | calls | lib/mirror.sh — Mirror cascade auto-recovery (T-1594, T-1591 Prevention #3). |
| [mirror](/docs/generated/lib-mirror) | tests | lib/mirror.sh — Mirror cascade auto-recovery (T-1594, T-1591 Prevention #3). |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_mirror_stderr_capture.yaml`*
*Last verified: 2026-05-14*
