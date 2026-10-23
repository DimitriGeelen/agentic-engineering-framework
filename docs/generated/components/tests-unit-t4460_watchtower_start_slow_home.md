# t4460_watchtower_start_slow_home

> T-4460 — under load the home page (GET /) took 68 s, the start's 5 s health check on / timed out, and the start only warned: the server kept running with watchtower.pid and watchtower.port but no watchtower.url, so every URL reader (the…

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4460_watchtower_start_slow_home.bats`

## What It Does

T-4460 — under load the home page (GET /) took 68 s, the start's 5 s health
check on / timed out, and the start only warned: the server kept running with
watchtower.pid and watchtower.port but no watchtower.url, so every URL reader
(the reviewer judge among them) reported "no running Watchtower".
The start now polls /api/_identity for WATCHTOWER_START_TIMEOUT seconds and,
on expiry, stops the server it launched and clears the triple.
A python3 shim on PATH replaces `python3 -m web.app` with a stub server whose
/api/_identity answers at once and whose / sleeps; every other python3 call
goes to the real interpreter. ufw is stubbed so start cannot touch the host
firewall. Teardown kills only the pid this test's project names.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4460_watchtower_start_slow_home.yaml`*
*Last verified: 2026-10-20*
