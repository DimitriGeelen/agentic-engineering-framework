# git_worker_commits

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/git_worker_commits.bats`

## What It Does

Unit tests for agents/git/lib/worker-commits.sh (T-2917)
Pins BOTH directions: a worker commit (GIT_AUTHOR_EMAIL matching the
dispatch+<id>@aef.local shape minted by lib/worker_identity.py /
lib/git-identity.sh:fw_worker_git_identity_env) is attributed to the worker
identity and surfaced by `worker-commits`; an operator commit in the SAME
repo is not — so the fix cannot pass by relabelling everything as a worker.

---
*Auto-generated from Component Fabric. Card: `tests-unit-git_worker_commits.yaml`*
*Last verified: 2026-08-11*
