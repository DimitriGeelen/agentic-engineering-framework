# reviewer_human_ac_mechanical_signal

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/reviewer_human_ac_mechanical_signal.bats`

## What It Does

T-1896 (T-1878 B): integration coverage for the new reviewer pattern
`human-ac-mechanical-signal` — runs `bin/fw reviewer` end-to-end against
synthetic task files, asserts the pattern fires (or doesn't) per design.
The Python unit tests in tests/unit/test_reviewer_human_ac_mechanical_signal.py
cover the detector in isolation; this bats file pins the higher-level wiring
(catalogue loading + scan_task orchestration + verdict rendering).

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-reviewer_human_ac_mechanical_signal.yaml`*
*Last verified: 2026-05-18*
