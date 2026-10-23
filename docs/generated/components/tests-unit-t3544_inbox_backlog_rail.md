# t3544_inbox_backlog_rail

> T-3544 / OBS-567 — the audit rail over the INBOUND consult backlog.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3544_inbox_backlog_rail.bats`

## What It Does

T-3544 / OBS-567 — the audit rail over the INBOUND consult backlog.
`fw_sidecar_inbox_stale_facts <root> [threshold_hours]` (lib/sidecar-audit.sh)
is the fact function behind the WARN in both `fw doctor` and audit.sh's
check_sidecar_ledger. It prints one tab-separated line per stale topic
TOPIC  UNREAD  AGE_HOURS  OLDEST_FROM
and shares the rc contract its two siblings established: rc 0 facts printed,
rc 1 nothing to check (caller stays SILENT), rc 2 the check could not run
(caller SAYS SO, never prints zeros for a check that did not happen).
It is hub-calling, like dm-stale and unlike the ledger: how many records sit
past our cursor has no durable local answer. So the tests here stub

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3544_inbox_backlog_rail.yaml`*
*Last verified: 2026-09-28*
