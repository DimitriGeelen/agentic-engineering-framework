# mirror

> lib/mirror.sh — Mirror cascade auto-recovery (T-1594, T-1591 Prevention #3).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/mirror.sh`

## What It Does

lib/mirror.sh — Mirror cascade auto-recovery (T-1594, T-1591 Prevention #3).
The cascade is: local → origin (OneDev) → github (mirror via OneDev
.onedev-buildspec.yml PushRepository job). When OneDev's mirror cron lags
or fails silently, github stays behind origin. T-1592 added detection in
`fw doctor`. This module closes the loop: when the move is fast-forward
safe, push the lagging mirror up to origin's HEAD. Diverged state is
logged but never auto-recovered — that requires human decision.
Public functions (called from bin/fw dispatcher):
mirror_main <subcommand> [args...]
Subcommands:

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_mirror_sync](/docs/generated/tests-unit-test_mirror_sync) | called_by | T-1594: Mirror cascade auto-recovery (T-1591 Prevention #3) |
| [test_mirror_sync](/docs/generated/tests-unit-test_mirror_sync) | tests_by | T-1594: Mirror cascade auto-recovery (T-1591 Prevention #3) |
| [test_mirror_stderr_capture](/docs/generated/tests-unit-test_mirror_stderr_capture) | called_by | T-1843 / T-1829 — lib/mirror.sh stderr capture on push-failed. |
| [test_mirror_stderr_capture](/docs/generated/tests-unit-test_mirror_stderr_capture) | tests_by | T-1843 / T-1829 — lib/mirror.sh stderr capture on push-failed. |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `lib-mirror.yaml`*
*Last verified: 2026-04-28*
