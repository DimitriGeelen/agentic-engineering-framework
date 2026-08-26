# episodic_worktree_mining

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/episodic_worktree_mining.bats`

## What It Does

T-3129 — episodic git mining in a LINKED GIT WORKTREE, and the shape of a
skipped measurement.
Two independent defects, two independent controls:
AC1/AC2 — the mining guard was `[ -d "$PROJECT_ROOT/.git" ]`. In a linked
worktree `.git` is a regular FILE holding a `gitdir:` pointer, so the test
was false and every mine_git_* call was skipped, even though the `git -C`
invocations inside the block work fine from a worktree. This class is
STRUCTURALLY INVISIBLE from a normal checkout: run the rest of the suite
from a plain clone and it passes. The control below therefore builds a
synthetic repo in a tmpdir and `git worktree add`s a linked worktree,

---
*Auto-generated from Component Fabric. Card: `tests-unit-episodic_worktree_mining.yaml`*
*Last verified: 2026-08-25*
