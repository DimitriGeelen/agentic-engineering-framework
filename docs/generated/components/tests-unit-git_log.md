# git_log

> Unit tests for git log (14 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/git_log.bats`

**Tags:** `git`, `log`, `bats`, `unit-test`

## What It Does

Unit tests for agents/git/lib/log.sh
Tests: do_log (argument parsing, git log filtering, traceability),
show_log_help, show_traceability

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [git](/docs/generated/agents-git-git) | calls | Git Agent - Structural Enforcement for Git Operations |
| [common](/docs/generated/agents-git-lib-common) | calls | Common utilities for git agent |
| [log](/docs/generated/agents-git-lib-log) | calls | Git Agent - Log subcommand |
| [log](/docs/generated/agents-git-lib-log) | tests | Git Agent - Log subcommand |
| [common](/docs/generated/agents-git-lib-common) | tests | Common utilities for git agent |

---
*Auto-generated from Component Fabric. Card: `tests-unit-git_log.yaml`*
*Last verified: 2026-04-05*
