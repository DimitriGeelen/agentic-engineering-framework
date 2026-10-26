# t4731_boundary_termlink_state_reads

> T-4731 (010-termlink T-3000): the project-boundary gate refused reads of TermLink's own per-account state (`sqlite3 ~/.termlink/outbound.sqlite`) as "another project".

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4731_boundary_termlink_state_reads.bats`

## What It Does

T-4731 (010-termlink T-3000): the project-boundary gate refused reads of TermLink's
own per-account state (`sqlite3 ~/.termlink/outbound.sqlite`) as "another project".
~/.termlink and the hub runtime dir are now READ zones, judged the same in the `~`,
`$HOME` and absolute spellings; writes there and reads of other projects still refuse.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4731_boundary_termlink_state_reads.yaml`*
*Last verified: 2026-10-25*
