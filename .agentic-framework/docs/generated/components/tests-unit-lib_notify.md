# lib_notify

> Unit tests for notify (7 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/lib_notify.bats`

**Tags:** `notify`, `bats`, `unit-test`

## What It Does

Unit tests for lib/notify.sh
Tests fw_notify() — push notification helper

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [notify](/docs/generated/lib-notify) | calls | Push notification wrapper — fw_notify() function sends alerts via skills-manager alert dispatcher. Fire-and-forget, opt-in via .context/notify-config.yaml. Used by check-tier0.sh, update-task.sh, audit.sh. |
| [notify](/docs/generated/lib-notify) | tests | Push notification wrapper — fw_notify() function sends alerts via skills-manager alert dispatcher. Fire-and-forget, opt-in via .context/notify-config.yaml. Used by check-tier0.sh, update-task.sh, audit.sh. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-lib_notify.yaml`*
*Last verified: 2026-04-05*
