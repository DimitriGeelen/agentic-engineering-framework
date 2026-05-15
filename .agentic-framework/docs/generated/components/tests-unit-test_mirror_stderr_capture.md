# test_mirror_stderr_capture

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_mirror_stderr_capture.bats`

## What It Does

T-1843 / T-1829 — lib/mirror.sh stderr capture on push-failed.
Origin: T-1828 RCA — the OneDev→GitHub mirror failed every 15min for 7+
hours with only "push-failed" in .context/working/.mirror-sync.log. Took
a consumer pickup to surface the actual blocking error (T-1603 hook).
This test pins that mirror_sync_one captures push stderr into the log on
failure so the next stall is diagnosable from logs alone.

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_mirror_stderr_capture.yaml`*
*Last verified: 2026-05-14*
