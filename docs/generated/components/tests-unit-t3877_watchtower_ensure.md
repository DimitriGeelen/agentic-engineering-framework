# t3877_watchtower_ensure

> T-3877: Watchtower is ensured at session start (lib/watchtower-ensure.sh, called detached from post-compact-resume.sh). After the 2026-10-05 reboot nothing started it — AEF's stayed down until started by hand, 055's ~80 min.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3877_watchtower_ensure.bats`

## What It Does

T-3877: Watchtower is ensured at session start (lib/watchtower-ensure.sh,
called detached from post-compact-resume.sh). After the 2026-10-05 reboot
nothing started it — AEF's stayed down until started by hand, 055's ~80 min.
A stub watchtower.sh records every start; the real one (and T-3876's port
rule) is exercised by t3662/t3876.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3877_watchtower_ensure.yaml`*
*Last verified: 2026-10-05*
