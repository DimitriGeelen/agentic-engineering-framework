# verify-acs

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/verify-acs.sh`

## What It Does

lib/verify-acs.sh — Automated Human AC evidence collection (T-824)
Scans work-completed tasks with unchecked Human ACs, runs automated checks
where possible, and reports results for human batch approval.
Usage:
source "$FRAMEWORK_ROOT/lib/verify-acs.sh"
do_verify_acs [--verbose] [T-XXX]
Origin: T-823 GO decision — 63% of Human ACs can be verified programmatically.

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `lib/verify-acs.sh` | calls |
| `lib/config.sh` | calls |

## Used By (4)

| Component | Relationship |
|-----------|-------------|
| `lib/verify-acs.sh` | called-by |
| `tests/unit/verify_acs.bats` | called-by |
| `lib/verify-acs.sh` | called_by |
| `tests/unit/verify_acs.bats` | called_by |

## Related

### Tasks
- T-824: fw verify-acs CLI — automated Human AC evidence collection for stale tasks
- T-840: verify-acs --auto-check — programmatic RUBBER-STAMP AC verification and auto-check

---
*Auto-generated from Component Fabric. Card: `lib-verify-acs.yaml`*
*Last verified: 2026-04-03*
