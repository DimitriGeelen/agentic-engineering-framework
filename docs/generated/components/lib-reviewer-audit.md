# audit

> Layer 3 audit cron (T-1443 v1.2, T-1484 v1.5b).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/reviewer/audit.py`

## What It Does

## Dependencies (10)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [__init__](/docs/generated/lib-reviewer-__init__) | calls | Reviewer agent (T-1443 v1.0). |
| [overrides](/docs/generated/lib-reviewer-overrides) | calls | Reviewer override mechanism (T-1443 v1.4). |
| [drift](/docs/generated/lib-reviewer-drift) | calls | Pass A drift detection (T-1483 v1.5). |
| [static_scan](/docs/generated/lib-reviewer-static_scan) | calls | Static-scan reviewer (T-1443 v1.0 → v1.5). |
| [reverify](/docs/generated/lib-reviewer-reverify) | calls | Pass B re-verification (T-1483 v1.5). |
| [__init__](/docs/generated/lib-reviewer-__init__) | uses | Reviewer agent (T-1443 v1.0). |
| [overrides](/docs/generated/lib-reviewer-overrides) | uses | Reviewer override mechanism (T-1443 v1.4). |
| [drift](/docs/generated/lib-reviewer-drift) | uses | Pass A drift detection (T-1483 v1.5). |
| [static_scan](/docs/generated/lib-reviewer-static_scan) | uses | Static-scan reviewer (T-1443 v1.0 → v1.5). |
| [reverify](/docs/generated/lib-reviewer-reverify) | uses | Pass B re-verification (T-1483 v1.5). |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_reviewer_audit_pass_a](/docs/generated/tests-unit-test_reviewer_audit_pass_a) | called_by | Unit tests for lib/reviewer/audit.py --pass-a corpus drift mode (T-1485 v1.5c). |
| [test_reviewer_audit_pass_b](/docs/generated/tests-unit-test_reviewer_audit_pass_b) | called_by | Unit tests for lib/reviewer/audit.py --pass-b corpus mode (T-1484 v1.5b). |
| [test_reviewer_audit_pass_a](/docs/generated/tests-unit-test_reviewer_audit_pass_a) | uses_by | Unit tests for lib/reviewer/audit.py --pass-a corpus drift mode (T-1485 v1.5c). |
| [test_reviewer_audit_pass_b](/docs/generated/tests-unit-test_reviewer_audit_pass_b) | uses_by | Unit tests for lib/reviewer/audit.py --pass-b corpus mode (T-1484 v1.5b). |

---
*Auto-generated from Component Fabric. Card: `lib-reviewer-audit.yaml`*
*Last verified: 2026-05-06*
