# test_reviewer_prose_mismatch

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_reviewer_prose_mismatch.bats`

## What It Does

T-1947 (L-409): integration coverage for `reviewer-prose-mismatch` —
the inverse of `human-ac-mechanical-signal`.
Mechanical signal: `[REVIEW]` AC whose Expected is grep-able → should be `[REVIEWER]`
Prose mismatch:    `[REVIEWER]` AC whose Expected is prose-quality → should be `[REVIEW]`
Origin: T-1811 AC#1 (`[REVIEWER] Updated CLAUDE.md section reads clearly`)
got no reviewer attention because the reviewer has no prose-quality detector.
Scanner reported CONCERN on Agent AC#3 — surface looked identical to "all clear
on prose". This bats file pins the structural catch.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_reviewer_prose_mismatch.yaml`*
*Last verified: 2026-05-20*
