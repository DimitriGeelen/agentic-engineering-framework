# t3154_doctor_agent_entry_scripts

> T-3154 — fw doctor's "Agent scripts executable" check iterated a hardcoded seven-item list and then printed "All agent scripts executable".

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3154_doctor_agent_entry_scripts.bats`

## What It Does

T-3154 — fw doctor's "Agent scripts executable" check iterated a hardcoded
seven-item list and then printed "All agent scripts executable". A consumer
(001-CashWeb) measured agents/designer/designer.sh at mode 644 in the same
run that doctor reported OK: the verdict named a set it never ran over.
The check now enumerates entry scripts from disk via agent_entry_scripts
(lib/exec-bit-drift.sh). These tests pin the enumerator against a temp
agents dir (so the real repo's modes are never touched) and the doctor
wiring against the live tree.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3154_doctor_agent_entry_scripts.yaml`*
*Last verified: 2026-10-20*
