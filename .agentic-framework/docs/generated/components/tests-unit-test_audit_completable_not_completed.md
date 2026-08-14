# test_audit_completable_not_completed

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_audit_completable_not_completed.bats`

## What It Does

T-2055 — Pin CTL-029, the active-side mirror of CTL-028. Catches tasks
where Agent ACs are 100% ticked but status remains started-work/issues
(shipped-but-unclosed — agent finished the work and forgot to run
`--status work-completed`).
Four shape cases covered:
(a) ### Agent + ### Human split — count Agent only
(b) ## Acceptance Criteria with no sub-headers — count all
(c) placeholder/template-only AC list — silent (no false WARN)
(d) partial-ticked (mixed [x] and [ ]) — silent

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_audit_completable_not_completed.yaml`*
*Last verified: 2026-05-27*
