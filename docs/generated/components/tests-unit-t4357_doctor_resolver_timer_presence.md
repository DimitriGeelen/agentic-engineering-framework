# t4357_doctor_resolver_timer_presence

> T-4357 (GH #100) — doctor's Autonomous Dispatch block must decide whether resolver-loop.timer is installed from the unit name in `systemctl list-unit-files` output, not from its exit code: systemd 245 exits 0 when no unit matches, which…

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4357_doctor_resolver_timer_presence.bats`

## What It Does

T-4357 (GH #100) — doctor's Autonomous Dispatch block must decide whether
resolver-loop.timer is installed from the unit name in `systemctl
list-unit-files` output, not from its exit code: systemd 245 exits 0 when no
unit matches, which made doctor say "installed but inactive" on hosts where
the timer was never installed.
The block under test is taken from bin/fw itself (from the section header to
the cron-registry read that follows it) and run against a stub systemctl.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4357_doctor_resolver_timer_presence.yaml`*
*Last verified: 2026-10-20*
