# fw_git

> Integration tests for fw git CLI — 6 tests covering help, status, and commit with task reference validation.

**Type:** test | **Subsystem:** framework-core | **Location:** `tests/integration/fw_git.bats`

**Tags:** `bats`, `integration-test`, `git`, `cli`

## What It Does

Integration tests for fw git subcommand
Tests the CLI interface for git operations:
fw git status  — task-aware git status
fw git commit  — commit with task reference validation
fw git help    — show help

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_git.yaml`*
*Last verified: 2026-03-30*
