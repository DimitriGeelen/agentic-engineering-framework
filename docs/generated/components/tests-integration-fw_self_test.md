# fw_self_test

> Integration tests for fw self-test (4 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/integration/fw_self_test.bats`

**Tags:** `fw-self-test`, `bats`, `integration-test`

## What It Does

Integration tests for fw self-test
Origin: T-947
T-4644: `fw self-test` runs every phase (~150 s). Each test used to run it
again, which took the file past the 900 s per-file integration cap under -j4.
Every assertion reads the same output, so the file runs it once and shares it.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Related

### Tasks
- T-947: Integration tests for fw costs and fw self-test commands

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_self_test.yaml`*
*Last verified: 2026-04-06*
