# fw_resume

> Integration tests for fw resume CLI — 5 tests covering help, quick, status, sync, and session file.

**Type:** test | **Subsystem:** framework-core | **Location:** `tests/integration/fw_resume.bats`

**Tags:** `bats`, `integration-test`, `resume`, `cli`

## What It Does

Integration tests for fw resume subcommand
Tests the CLI interface for session recovery:
fw resume status  — full state synthesis
fw resume sync    — fix stale working memory
fw resume quick   — one-line summary

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_resume.yaml`*
*Last verified: 2026-03-30*
