# mirror

> TODO: describe what this component does

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

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_mirror_sync](/docs/generated/tests-unit-test_mirror_sync) | called_by | TODO: describe what this component does |
| [test_mirror_sync](/docs/generated/tests-unit-test_mirror_sync) | tests_by | TODO: describe what this component does |
| [test_mirror_stderr_capture](/docs/generated/tests-unit-test_mirror_stderr_capture) | called_by | TODO: describe what this component does |
| [test_mirror_stderr_capture](/docs/generated/tests-unit-test_mirror_stderr_capture) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-mirror.yaml`*
*Last verified: 2026-04-28*
