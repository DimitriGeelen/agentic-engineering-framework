# test_consumer_recover

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_consumer_recover.bats`

## What It Does

T-2235 — fw consumer-recover wrapper (authorised under T-2233 GO).
Tests cover the 8 cases in docs/reports/T-2233-consumer-recover-design.md §8.
Transport is mocked via PATH shadowing — no real SSH or TermLink calls.

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [consumer-recover](/docs/generated/lib-consumer-recover) | calls | TODO: describe what this component does |
| [consumer-recover](/docs/generated/lib-consumer-recover) | tests | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_consumer_recover.yaml`*
*Last verified: 2026-06-07*
