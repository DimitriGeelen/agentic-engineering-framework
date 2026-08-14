# test_audit_revert_chain

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_audit_revert_chain.bats`

## What It Does

T-2058 — Pin audit.sh revert-chain suppression. Origin: 3 historical commits
(b5b52783, 3e8f23c8, 1fe4aace) referencing task files T-1906/T-1907 that were
deliberately deleted via T-1687's revert chain ("revert T-1906/T-1907
fake-prevention chain"). Audit was emitting a "references non-existent task"
WARN for each of the 3 commits even though the orphan was intentional.
Rule: when a commit references a missing task file, audit looks for a later
commit message matching /revert.*T-NNNN/ (case-insensitive). If found, the
WARN is suppressed — the deletion was an explicit decision in history, not a
governance gap.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_audit_revert_chain.yaml`*
*Last verified: 2026-05-27*
