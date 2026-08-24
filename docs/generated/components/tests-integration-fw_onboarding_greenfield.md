# fw_onboarding_greenfield

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/integration/fw_onboarding_greenfield.bats`

## What It Does

T-2850 — greenfield onboarding integration coverage.
WHY THIS FILE EXISTS
Four defects reached the operator's hands in a single by-hand onboarding run
on 2026-08-06 (T-2839 fw upgrade, T-2843 path ambiguity, T-2844 cron drift,
T-2845 upgrade advisory target). Every one of them had, or immediately got, a
green unit test. None was caught before the operator saw it, because the only
integration coverage for onboarding was two assertions that a command printed
a string containing "nboarding" — neither of which checked an exit status.
The unit tests answer "is this predicate correct?". They cannot answer "what
does an operator see after `fw init`?", because that answer is a property of

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_onboarding_greenfield.yaml`*
*Last verified: 2026-08-07*
