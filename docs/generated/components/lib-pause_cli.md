# pause_cli

> CLI dispatcher for `fw pause`. T-1809 (dispatch-safety slice 5).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/pause_cli.py`

## What It Does

Put lib/ on path so siblings import cleanly.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [dispatch_pause](/docs/generated/lib-dispatch_pause) | uses | Paused-dispatch helpers for the operator review queue. |
| [pause_resolve](/docs/generated/lib-pause_resolve) | uses | Pause re-dispatch chain — capture operator's answer + fire a retry via Resolver. |

---
*Auto-generated from Component Fabric. Card: `lib-pause_cli.yaml`*
*Last verified: 2026-05-13*
