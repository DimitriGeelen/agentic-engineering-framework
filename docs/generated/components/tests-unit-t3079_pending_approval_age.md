# t3079_pending_approval_age

> T-3079: no rail detected a Tier 0 approval request left sitting unanswered. Pending cards (.context/approvals/pending-*.yaml) were read only by pull surfaces (/approvals, fw approvals pending); three sat unseen for months.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3079_pending_approval_age.bats`

## What It Does

T-3079: no rail detected a Tier 0 approval request left sitting unanswered.
Pending cards (.context/approvals/pending-*.yaml) were read only by pull
surfaces (/approvals, fw approvals pending); three sat unseen for months.
lib/approval_queue_age.py is the shared age predicate; fw doctor and fw audit
(enforcement section) WARN on cards older than APPROVAL_PENDING_WARN_HOURS.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3079_pending_approval_age.yaml`*
*Last verified: 2026-10-20*
