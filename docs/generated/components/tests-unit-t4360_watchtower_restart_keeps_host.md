# t4360_watchtower_restart_keeps_host

> T-4360 (GitHub #103) — a plain `watchtower restart` from a shell without FW_HOST (an agent session) re-resolved the bind to the 0.0.0.0 default and silently widened a host-specific instance to every interface.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4360_watchtower_restart_keeps_host.bats`

## What It Does

T-4360 (GitHub #103) — a plain `watchtower restart` from a shell without FW_HOST
(an agent session) re-resolved the bind to the 0.0.0.0 default and silently
widened a host-specific instance to every interface. Restart must come back on
the running address; an explicit FW_HOST still wins and WARNs when it widens.
127.0.0.2 is a second loopback address, so the test needs no LAN interface and a
widened listener (0.0.0.0) is distinguishable from the kept one.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4360_watchtower_restart_keeps_host.yaml`*
*Last verified: 2026-11-11*
