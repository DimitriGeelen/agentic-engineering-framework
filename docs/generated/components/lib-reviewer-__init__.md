# __init__

> Reviewer agent (T-1443 v1.0).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/reviewer/__init__.py`

## What It Does

## Used By (12)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit](/docs/generated/lib-reviewer-audit) | called_by | Layer 3 audit cron (T-1443 v1.2, T-1484 v1.5b). |
| [test_reviewer_audit_pass_b](/docs/generated/tests-unit-test_reviewer_audit_pass_b) | called_by | Unit tests for lib/reviewer/audit.py --pass-b corpus mode (T-1484 v1.5b). |
| [test_reviewer_overrides](/docs/generated/tests-unit-test_reviewer_overrides) | called_by | Unit tests for lib/reviewer/overrides.py (T-1443 v1.4). |
| [test_reviewer_human_ac_mechanical_signal](/docs/generated/tests-unit-test_reviewer_human_ac_mechanical_signal) | called_by | T-1896 (T-1878 B): tests for detect_human_ac_mechanical_signal. |
| [test_reviewer_ac_evidence_untick](/docs/generated/tests-unit-test_reviewer_ac_evidence_untick) | called_by | T-2155 (T-1761 prevention): tests for detect_ac_evidence_untick. |
| [audit](/docs/generated/lib-reviewer-audit) | uses_by | Layer 3 audit cron (T-1443 v1.2, T-1484 v1.5b). |
| [test_reviewer_ac_evidence_untick](/docs/generated/tests-unit-test_reviewer_ac_evidence_untick) | uses_by | T-2155 (T-1761 prevention): tests for detect_ac_evidence_untick. |
| [test_reviewer_audit_pass_b](/docs/generated/tests-unit-test_reviewer_audit_pass_b) | uses_by | Unit tests for lib/reviewer/audit.py --pass-b corpus mode (T-1484 v1.5b). |
| [test_reviewer_human_ac_mechanical_signal](/docs/generated/tests-unit-test_reviewer_human_ac_mechanical_signal) | uses_by | T-1896 (T-1878 B): tests for detect_human_ac_mechanical_signal. |
| [test_reviewer_overrides](/docs/generated/tests-unit-test_reviewer_overrides) | uses_by | Unit tests for lib/reviewer/overrides.py (T-1443 v1.4). |
| [test_reviewer_decaying_task_path_ref](/docs/generated/tests-unit-test_reviewer_decaying_task_path_ref) | called_by | T-3274: pin the decaying-`.tasks/active/` verification-reference detector. |
| [test_reviewer_decaying_task_path_ref](/docs/generated/tests-unit-test_reviewer_decaying_task_path_ref) | uses_by | T-3274: pin the decaying-`.tasks/active/` verification-reference detector. |

---
*Auto-generated from Component Fabric. Card: `lib-reviewer-__init__.yaml`*
*Last verified: 2026-05-06*
