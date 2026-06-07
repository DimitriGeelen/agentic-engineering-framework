# verify-acs

> Scans work-completed tasks with unchecked Human ACs and runs automated evidence collection where programmatic verification is possible

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/verify-acs.sh`

## What It Does

lib/verify-acs.sh — Automated Human AC evidence collection (T-824)
Scans work-completed tasks with unchecked Human ACs, runs automated checks
where possible, and reports results for human batch approval.
Usage:
source "$FRAMEWORK_ROOT/lib/verify-acs.sh"
do_verify_acs [--verbose] [T-XXX]
Origin: T-823 GO decision — 63% of Human ACs can be verified programmatically.

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [verify-acs](/docs/generated/lib-verify-acs) | calls | Scans work-completed tasks with unchecked Human ACs and runs automated evidence collection where programmatic verification is possible |
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |
| [watchtower](/docs/generated/lib-watchtower) | calls | Detects the running Watchtower instance URL and provides browser-open helpers for scripts that need to link to the web UI |

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [verify-acs](/docs/generated/lib-verify-acs) | called-by | Scans work-completed tasks with unchecked Human ACs and runs automated evidence collection where programmatic verification is possible |
| [verify_acs](/docs/generated/tests-unit-verify_acs) | called-by | Unit tests for verify acs (6 tests) |
| [verify-acs](/docs/generated/lib-verify-acs) | called_by | Scans work-completed tasks with unchecked Human ACs and runs automated evidence collection where programmatic verification is possible |
| [verify_acs](/docs/generated/tests-unit-verify_acs) | called_by | Unit tests for verify acs (6 tests) |
| [verify_acs](/docs/generated/tests-unit-verify_acs) | tests_by | Unit tests for verify acs (6 tests) |

## Related

### Tasks
- T-824: fw verify-acs CLI — automated Human AC evidence collection for stale tasks
- T-840: verify-acs --auto-check — programmatic RUBBER-STAMP AC verification and auto-check

---
*Auto-generated from Component Fabric. Card: `lib-verify-acs.yaml`*
*Last verified: 2026-04-03*
