# git_common

> Unit tests for git common (10 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/git_common.bats`

**Tags:** `git`, `common`, `bats`, `unit-test`

## What It Does

Unit tests for agents/git/lib/common.sh
Tests pure functions: extract_task_id, task_exists, get_task_name

## Dependencies (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [git](/docs/generated/agents-git-git) | calls | Git Agent - Structural Enforcement for Git Operations |
| [compat](/docs/generated/lib-compat) | calls | Compatibility shims: bash 3.2 (macOS) POSIX-safe replacements for declare -A and other bashisms. |
| [tasks](/docs/generated/lib-tasks) | calls | fw task subcommand dispatcher: routes task create/update/list/verify/review to agents/task-create/ scripts. |
| [common](/docs/generated/agents-git-lib-common) | calls | Common utilities for git agent |
| [common](/docs/generated/agents-git-lib-common) | tests | Common utilities for git agent |
| [compat](/docs/generated/lib-compat) | tests | Compatibility shims: bash 3.2 (macOS) POSIX-safe replacements for declare -A and other bashisms. |
| [tasks](/docs/generated/lib-tasks) | tests | fw task subcommand dispatcher: routes task create/update/list/verify/review to agents/task-create/ scripts. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-git_common.yaml`*
*Last verified: 2026-04-05*
