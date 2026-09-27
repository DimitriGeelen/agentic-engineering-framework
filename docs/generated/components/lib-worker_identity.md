# worker_identity

> worker_identity — the git identity a dispatch-spawned worker commits under (T-2917).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/worker_identity.py`

## What It Does

Anchors the format both implementations must match — pinned by
tests/unit/worker_identity.py and tests/unit/git_identity_worker_env.bats.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [init](/docs/generated/lib-init) | calls | fw init - Bootstrap a new project with the Agentic Engineering Framework |
| [git-identity](/docs/generated/lib-git-identity) | calls | lib/git-identity.sh — one answer to "can this machine commit?" (T-2883) |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [resolver](/docs/generated/lib-resolver) | uses_by | Resolver — workflow lookup, prompt assembly, variant selection, telemetry. |
| [git_worker_commits](/docs/generated/tests-unit-git_worker_commits) | tests_by | Unit tests for agents/git/lib/worker-commits.sh (T-2917) |

---
*Auto-generated from Component Fabric. Card: `lib-worker_identity.yaml`*
*Last verified: 2026-09-03*
