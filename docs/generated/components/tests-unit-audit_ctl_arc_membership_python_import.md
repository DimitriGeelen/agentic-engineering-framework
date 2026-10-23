# audit_ctl_arc_membership_python_import

> T-3516 (OBS-546): pin the ctl-arc-membership-python-import audit check.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/audit_ctl_arc_membership_python_import.bats`

## What It Does

T-3516 (OBS-546): pin the ctl-arc-membership-python-import audit check.
Sibling of audit_ctl_arc_tag_only_pattern.bats (T-1881), which requires the
literal token `grep` and so cannot see a Python reinvention. This check
inverts to an import allowlist for the Python half: a file that iterates
the task corpus AND references `arc_id` within a 60-line window, without
importing the canonical `arc_membership` module, is flagged.
Verifies that:
1. A clean tree (canonical import present) -> PASS
2. A synthetic reinvention (corpus iteration + arc_id, no import) -> FAIL
3. A comment-only mention of the pattern does NOT trip the check

---
*Auto-generated from Component Fabric. Card: `tests-unit-audit_ctl_arc_membership_python_import.yaml`*
*Last verified: 2026-09-27*
