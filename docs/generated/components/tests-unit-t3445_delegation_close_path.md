# t3445_delegation_close_path

> T-3445 — the delegated close path, end to end, on two fixtures.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3445_delegation_close_path.bats`

## What It Does

T-3445 — the delegated close path, end to end, on two fixtures.
Rewritten for T-4916 (operator 2026-10-30, "b"): deterministic criteria are no
longer converted to `[REVIEWER]` Agent criteria for the static-scan auto-tick
(T-4778 left converted criteria with no close path). They stay under ### Human,
reviewer-judged, and close on a recorded green verdict through the verdict ledger
(test_t3579_verdict_ledger.py pins that half). Every step here is the shipped
code — `fw task delegate`, `fw reviewer`, `update-task.sh`. Nothing is stubbed.
Fixture 1 — two deterministic Human criteria. Delegate reports both
reviewer-judged and writes nothing; the static scan ticks nothing;
the close is refused until a verdict exists.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3445_delegation_close_path.yaml`*
*Last verified: 2026-09-24*
