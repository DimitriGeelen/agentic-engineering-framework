# fw_notify

> Integration tests for fw notify CLI — 10 tests covering help, status, enable, disable, toggle, test-disabled, invalid subcommand, setup.

**Type:** test | **Subsystem:** framework-core | **Location:** `tests/integration/fw_notify.bats`

**Tags:** `bats`, `integration-test`, `ntfy`, `notifications`

## What It Does

Integration tests for fw notify subcommand (T-710)
Tests the CLI interface for push notification management:
fw notify status    — show config state
fw notify enable    — set enabled=true
fw notify disable   — set enabled=false
fw notify setup     — prerequisite check and guide
fw notify test      — send test (requires enabled)
fw notify           — show help

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `bin/fw` | calls |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_notify.yaml`*
*Last verified: 2026-03-29*
