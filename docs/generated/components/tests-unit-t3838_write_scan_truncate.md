# t3838_write_scan_truncate

> T-3838 — lib/shell_write_scan.py did not treat `truncate -s 0 <task file>` as a write (ring20-dashboard T-2460, msg 6b1ada91).

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3838_write_scan_truncate.bats`

## What It Does

T-3838 — lib/shell_write_scan.py did not treat `truncate -s 0 <task file>` as a
write (ring20-dashboard T-2460, msg 6b1ada91). `truncate` was known only to the
T-4149 boundary mode (_ALL_OPERANDS); the default scan, which check-human-ac-tick
runs, fell through and returned no hit, so the shell write was let through.
Two claims, as in t3695: the command really empties the task file (VECTOR), and
the hook refuses it under CLAUDECODE=1 (GUARD). Controls keep truncate of an
unguarded path and the -s/-r value word from being mistaken for a target.
`! cmd` at statement position is INERT in bats (L-628) — use `|| false`.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3838_write_scan_truncate.yaml`*
*Last verified: 2026-10-21*
