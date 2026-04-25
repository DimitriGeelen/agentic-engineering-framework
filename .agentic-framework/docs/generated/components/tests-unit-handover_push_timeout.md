# handover_push_timeout

> Unit tests for T-1277 — verify handover.sh wraps git push with timeout so an unreachable remote (e.g. onedev VPN down) cannot stall the auto-handover hook. Default bound 15s, override via FW_HANDOVER_PUSH_TIMEOUT.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/handover_push_timeout.bats`

**Tags:** `tests`, `unit`, `handover`, `timeout`, `T-1277`

## What It Does

T-1277 — handover.sh wraps `git push` with `timeout` so an unreachable
remote (e.g. onedev VPN down) cannot stall the auto-handover hook for
hours. Default bound 15s, override via FW_HANDOVER_PUSH_TIMEOUT.

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `agents/handover/handover.sh` | calls |
| `agents/context/checkpoint.sh` | calls |

---
*Auto-generated from Component Fabric. Card: `tests-unit-handover_push_timeout.yaml`*
*Last verified: 2026-04-19*
