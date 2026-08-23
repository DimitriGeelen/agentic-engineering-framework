# t3111_worktree_reexec

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3111_worktree_reexec.bats`

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

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3111_worktree_reexec.yaml`*
*Last verified: 2026-08-22*
