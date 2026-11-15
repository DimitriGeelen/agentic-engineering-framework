# t5131_audit_record_no_overwrite

> T-5131 (832 T-763 / RA-052, operator ruling): a dated audit record is never overwritten.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5131_audit_record_no_overwrite.bats`

## What It Does

T-5131 (832 T-763 / RA-052, operator ruling): a dated audit record is never overwritten. A
second manual run on the same date moves the earlier <date>.yaml aside to
<date>-<HHMM of its mtime>.yaml (counter on a clash); <date>.yaml is always the newest.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5131_audit_record_no_overwrite.yaml`*
*Last verified: 2026-11-14*
