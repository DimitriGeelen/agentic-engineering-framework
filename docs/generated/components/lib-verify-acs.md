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

## Related

### Tasks
- T-840: verify-acs --auto-check — programmatic RUBBER-STAMP AC verification and auto-check

---
*Auto-generated from Component Fabric. Card: `lib-verify-acs.yaml`*
*Last verified: 2026-04-03*
