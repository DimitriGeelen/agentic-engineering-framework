# git_common

> Unit tests for git common (10 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/git_common.bats`

**Tags:** `git`, `common`, `bats`, `unit-test`

## What It Does

Unit tests for agents/git/lib/common.sh
Tests pure functions: extract_task_id, task_exists, get_task_name

## Dependencies (7)

| Target | Relationship |
|--------|-------------|
| `agents/git/git.sh` | calls |
| `lib/compat.sh` | calls |
| `lib/tasks.sh` | calls |
| `agents/git/lib/common.sh` | calls |
| `agents/git/lib/common.sh` | tests |
| `lib/compat.sh` | tests |
| `lib/tasks.sh` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-git_common.yaml`*
*Last verified: 2026-04-05*
