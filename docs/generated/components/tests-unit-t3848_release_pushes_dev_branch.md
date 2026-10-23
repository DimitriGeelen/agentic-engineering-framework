# t3848_release_pushes_dev_branch

> T-3848: v1.8.1 pushed master + tag atomically (T-3822) but never pushed the development branch carrying the VERSION-reconcile commit, so origin/bleeding-edge ended 1 commit BEHIND origin/master — the release-train invariant (dev branch is…

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3848_release_pushes_dev_branch.bats`

## What It Does

T-3848: v1.8.1 pushed master + tag atomically (T-3822) but never pushed the
development branch carrying the VERSION-reconcile commit, so
origin/bleeding-edge ended 1 commit BEHIND origin/master — the release-train
invariant (dev branch is master's only writer, master never leads it) broken
on the remote the moment the release finished.
Fix: the checked-out dev branch rides in the SAME --atomic push, and the
T-3819 pre-flight grades it on every remote too. Throwaway repos, file://.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3848_release_pushes_dev_branch.yaml`*
*Last verified: 2026-10-21*
