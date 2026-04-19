# handover_push_timeout

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/handover_push_timeout.bats`

## What It Does

T-1277 — handover.sh wraps `git push` with `timeout` so an unreachable
remote (e.g. onedev VPN down) cannot stall the auto-handover hook for
hours. Default bound 15s, override via FW_HANDOVER_PUSH_TIMEOUT.

---
*Auto-generated from Component Fabric. Card: `tests-unit-handover_push_timeout.yaml`*
*Last verified: 2026-04-18*
