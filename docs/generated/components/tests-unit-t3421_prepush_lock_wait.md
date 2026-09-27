# t3421_prepush_lock_wait

> T-3421 — the pre-push audit-lock wait is derived from the measured audit.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3421_prepush_lock_wait.bats`

## What It Does

T-3421 — the pre-push audit-lock wait is derived from the measured audit.
T-3297's 90s default expired before the ~292s structure audit it waited for
could finish. `fw_prepush_lock_wait_default <root>` (lib/prepush-lock-wait.sh)
reads the last measured `structure` seconds from the timing ledger and
returns ceil(1.25x) clamped to [90, 600], or 360 with no usable ledger.
Hermetic: every ledger here is a fixture under a tmpdir.

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [prepush-lock-wait](/docs/generated/lib-prepush-lock-wait) | tests | lib/prepush-lock-wait.sh — T-3421: derive the pre-push audit-lock wait from the measured audit, instead of asserting it. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | tests | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [hooks](/docs/generated/agents-git-lib-hooks) | tests | Git Agent - Hook installation subcommand |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3421_prepush_lock_wait.yaml`*
*Last verified: 2026-09-22*
