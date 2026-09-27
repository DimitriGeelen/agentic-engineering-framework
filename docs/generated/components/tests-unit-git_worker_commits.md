# git_worker_commits

> Unit tests for agents/git/lib/worker-commits.sh (T-2917)

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/git_worker_commits.bats`

## What It Does

Unit tests for agents/git/lib/worker-commits.sh (T-2917)
Pins BOTH directions: a worker commit (GIT_AUTHOR_EMAIL matching the
dispatch+<id>@aef.local shape minted by lib/worker_identity.py /
lib/git-identity.sh:fw_worker_git_identity_env) is attributed to the worker
identity and surfaced by `worker-commits`; an operator commit in the SAME
repo is not — so the fix cannot pass by relabelling everything as a worker.

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [common](/docs/generated/agents-git-lib-common) | calls | Common utilities for git agent |
| [git-identity](/docs/generated/lib-git-identity) | tests | lib/git-identity.sh — one answer to "can this machine commit?" (T-2883) |
| [common](/docs/generated/agents-git-lib-common) | tests | Common utilities for git agent |
| [worker-commits](/docs/generated/agents-git-lib-worker-commits) | tests | Git Agent - worker-commits subcommand (T-2917) |
| [worker_identity](/docs/generated/lib-worker_identity) | tests | worker_identity — the git identity a dispatch-spawned worker commits under (T-2917). |

---
*Auto-generated from Component Fabric. Card: `tests-unit-git_worker_commits.yaml`*
*Last verified: 2026-08-11*
