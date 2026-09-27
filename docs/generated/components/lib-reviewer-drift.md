# drift

> Pass A drift detection (T-1483 v1.5).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/reviewer/drift.py`

## What It Does

File reference extraction
Matches: relative paths starting with ./ or just dir/file.ext, absolute paths,
and common stems mentioned in test/grep/python -c contexts.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [reverify](/docs/generated/lib-reviewer-reverify) | calls | Pass B re-verification (T-1483 v1.5). |

## Used By (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit](/docs/generated/lib-reviewer-audit) | called_by | Layer 3 audit cron (T-1443 v1.2, T-1484 v1.5b). |
| [drift_cli](/docs/generated/lib-reviewer-drift_cli) | called_by | CLI shim for drift detection (T-1483 v1.5 Pass A). |
| [test_reviewer_audit_pass_a](/docs/generated/tests-unit-test_reviewer_audit_pass_a) | called_by | Unit tests for lib/reviewer/audit.py --pass-a corpus drift mode (T-1485 v1.5c). |
| [audit](/docs/generated/lib-reviewer-audit) | uses_by | Layer 3 audit cron (T-1443 v1.2, T-1484 v1.5b). |
| [drift_cli](/docs/generated/lib-reviewer-drift_cli) | uses_by | CLI shim for drift detection (T-1483 v1.5 Pass A). |
| [test_reviewer_audit_pass_a](/docs/generated/tests-unit-test_reviewer_audit_pass_a) | uses_by | Unit tests for lib/reviewer/audit.py --pass-a corpus drift mode (T-1485 v1.5c). |

---
*Auto-generated from Component Fabric. Card: `lib-reviewer-drift.yaml`*
*Last verified: 2026-05-06*
