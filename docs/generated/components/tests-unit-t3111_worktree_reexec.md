# t3111_worktree_reexec

> T-3111: fw re-execs the AUTHORITY's binary from a linked worktree (R7 leg L2).

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3111_worktree_reexec.bats`

## What It Does

T-3111: fw re-execs the AUTHORITY's binary from a linked worktree (R7 leg L2).
The fixture is a REAL `git worktree add`, for the same reason T-3112's was: the
claim is about git's worktree model — git-dir differs from git-common-dir in a
linked checkout and collapses in the main one — and a fabricated directory
layout asserts nothing about that.
THE OBSERVABLE. "Did it re-exec?" is invisible from the outside unless the two
binaries disagree about something, so the fixture makes them disagree twice:
1. VERSION differs (AUTHORITY vs REPLICA). `fw --version` reads the file next
to whichever binary is running, so the string names the winner.
2. `_stub_authority` replaces the AUTHORITY's bin/fw with a script that prints

## Dependencies (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [worktree-identity](/docs/generated/lib-worktree-identity) | tests | lib/worktree-identity.sh — "is this checkout a replica?" (T-3111, R7) |
| [hook-parity](/docs/generated/lib-hook-parity) | tests | lib/hook-parity.sh — the enforcement-baseline comparison predicate (T-3112, R7 leg 3) |
| [hook_parity](/docs/generated/lib-hook_parity) | tests | Hook-set extraction and comparison — ONE definition, every caller (T-3112/T-3113). |
| [paths](/docs/generated/lib-paths) | tests | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [worktree-identity](/docs/generated/lib-worktree-identity) | calls | lib/worktree-identity.sh — "is this checkout a replica?" (T-3111, R7) |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3111_worktree_reexec.yaml`*
*Last verified: 2026-08-22*
