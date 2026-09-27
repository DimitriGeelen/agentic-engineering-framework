# prepush-lock-wait

> lib/prepush-lock-wait.sh — T-3421: derive the pre-push audit-lock wait from the measured audit, instead of asserting it.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/prepush-lock-wait.sh`

## What It Does

lib/prepush-lock-wait.sh — T-3421: derive the pre-push audit-lock wait from
the measured audit, instead of asserting it.
T-3297 gave the pre-push gate a bounded wait for the audit lock, default 90s,
on the premise that the contended audit "finishes within a minute or two".
The framework's own timing ledger (.context/audits/full-audit-timing.yaml,
T-3127) measures `--section structure` — the very section the gate runs —
at ~292s. A 90s wait therefore expires before the audit it waits for can
finish, so every contended push fails, and its retry re-runs a fresh 292s
audit that holds the lock against everyone else. Measured 2026-09-22 with
five concurrent writers: 10 + 8 + 25 lock hits across three pushers in one

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hooks](/docs/generated/agents-git-lib-hooks) | called_by | Git Agent - Hook installation subcommand |
| [t3421_prepush_lock_wait](/docs/generated/tests-unit-t3421_prepush_lock_wait) | tests_by | T-3421 — the pre-push audit-lock wait is derived from the measured audit. |

---
*Auto-generated from Component Fabric. Card: `lib-prepush-lock-wait.yaml`*
*Last verified: 2026-09-22*
