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

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `tests/unit/test_mirror_sync.bats` | called_by |
| `tests/unit/test_mirror_sync.bats` | tests_by |

---
*Auto-generated from Component Fabric. Card: `lib-mirror.yaml`*
*Last verified: 2026-04-28*
