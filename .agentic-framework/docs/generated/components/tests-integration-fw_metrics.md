# fw_metrics

> Integration tests for fw metrics CLI — 4 tests covering dashboard, task counts, and predict.

**Type:** test | **Subsystem:** framework-core | **Location:** `tests/integration/fw_metrics.bats`

**Tags:** `bats`, `integration-test`, `metrics`, `cli`

## What It Does

Integration tests for fw metrics subcommand
Tests the CLI interface for framework metrics:
fw metrics            — show metrics dashboard
fw metrics dashboard  — same as above
fw metrics predict    — effort prediction

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_metrics.yaml`*
*Last verified: 2026-03-30*
