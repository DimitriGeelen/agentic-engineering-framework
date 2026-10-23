# t2756_upgrade_autoclone_downgrade_guard

> T-2756: bare `fw upgrade` from a consumer auto-clones the upstream and hands off to the CLONE's bin/fw (T-1634).

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t2756_upgrade_autoclone_downgrade_guard.bats`

## What It Does

T-2756: bare `fw upgrade` from a consumer auto-clones the upstream and hands off
to the CLONE's bin/fw (T-1634). The downgrade guards (T-1839 pin, T-1912
runtime) lived only in the child, so an upstream whose fw predates them — a
master lagging the consumer's bleeding-edge commit, a stale fork, an old tag —
silently downgraded the consumer. The parent now decides ahead/diverged against
the clone's history before any of the clone's code runs.
Fixture: upstream default branch `master` at commit A, `bleeding-edge` at B on
top of it. The upstream bin/fw is GUARDLESS: it rewrites the pin to 1.0.0 and
leaves a marker. The consumer pins B (ahead of master) or A (control: same).

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2756_upgrade_autoclone_downgrade_guard.yaml`*
*Last verified: 2026-10-21*
