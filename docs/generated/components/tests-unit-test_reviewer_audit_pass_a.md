# test_reviewer_audit_pass_a

> Unit tests for lib/reviewer/audit.py --pass-a corpus drift mode (T-1485 v1.5c).

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_reviewer_audit_pass_a.py`

## What It Does

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit](/docs/generated/lib-reviewer-audit) | calls | Layer 3 audit cron (T-1443 v1.2, T-1484 v1.5b). |
| [drift](/docs/generated/lib-reviewer-drift) | calls | Pass A drift detection (T-1483 v1.5). |
| [audit](/docs/generated/lib-reviewer-audit) | uses | Layer 3 audit cron (T-1443 v1.2, T-1484 v1.5b). |
| [drift](/docs/generated/lib-reviewer-drift) | uses | Pass A drift detection (T-1483 v1.5). |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_reviewer_audit_pass_a.yaml`*
*Last verified: 2026-04-26*
