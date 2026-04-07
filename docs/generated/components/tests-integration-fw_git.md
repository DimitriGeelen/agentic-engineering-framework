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

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `bin/fw` | calls |

---
*Auto-generated from Component Fabric. Card: `tests-integration-fw_git.yaml`*
*Last verified: 2026-03-30*
