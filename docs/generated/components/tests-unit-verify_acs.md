# verify_acs

> Unit tests for verify acs (6 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/verify_acs.bats`

**Tags:** `verify-acs`, `bats`, `unit-test`

## What It Does

Unit tests for fw verify-acs (T-824)

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [verify-acs](/docs/generated/lib-verify-acs) | calls | Scans work-completed tasks with unchecked Human ACs and runs automated evidence collection where programmatic verification is possible |
| [verify-acs](/docs/generated/lib-verify-acs) | tests | Scans work-completed tasks with unchecked Human ACs and runs automated evidence collection where programmatic verification is possible |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Related

### Tasks
- T-824: fw verify-acs CLI — automated Human AC evidence collection for stale tasks

---
*Auto-generated from Component Fabric. Card: `tests-unit-verify_acs.yaml`*
*Last verified: 2026-04-05*
