# t4239_default_bind_loopback

> T-4239 (dimitri-mint-dev T-118 claim 11; GitHub #103) — Watchtower has no login and can record Human decisions, yet a fresh start with nothing configured listened on every interface.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4239_default_bind_loopback.bats`

## What It Does

T-4239 (dimitri-mint-dev T-118 claim 11; GitHub #103) — Watchtower has no login and
can record Human decisions, yet a fresh start with nothing configured listened on
every interface. The default is now 127.0.0.1 (operator, 2026-11-11); opening it
to the network is an explicit `fw config set HOST 0.0.0.0`.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4239_default_bind_loopback.yaml`*
*Last verified: 2026-11-11*
