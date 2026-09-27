# unit-suite

> Scheduled tests/unit corpus runner — executes both unit legs nightly and writes the machine-readable report surfaced by fw audit check_unit_suite_report (T-3302)

**Type:** script | **Subsystem:** audit | **Location:** `agents/audit/unit-suite.sh`

## What It Does

agents/audit/unit-suite.sh — T-3302: scheduled tests/unit corpus run.
Nothing ran tests/unit on a schedule: the daily audit's invariant-suite line
covers tests/lint ONLY, so unit reds sat invisible until an adjacent run
tripped over them (two found by accident on 2026-09-06 — OBS-359/OBS-360).
This runner executes both legs of the unit corpus nightly and writes a
machine-readable report that `fw audit` surfaces (check_unit_suite_report).
Locking (A1): the runner takes its OWN overlap lock and skips (logged,
exit 0) when it is already held. It must NEVER take the audit lock
(.context/locks/audit.lock): tests/unit contains suites that spawn
`audit.sh --section structure`, so a runner holding the audit lock would

---
*Auto-generated from Component Fabric. Card: `agents-audit-unit-suite.yaml`*
*Last verified: 2026-09-08*
