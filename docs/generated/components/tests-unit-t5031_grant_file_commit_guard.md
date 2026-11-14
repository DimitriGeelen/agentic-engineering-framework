# t5031_grant_file_commit_guard

> T-5031 (ring20-dashboard a14cb4c1, HIGH; G-129): a commit under agent control (CLAUDECODE=1) may not change policy/access-grants.yaml — the file is read from HEAD, so the commit is what makes a grant count.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5031_grant_file_commit_guard.bats`

## What It Does

T-5031 (ring20-dashboard a14cb4c1, HIGH; G-129): a commit under agent control (CLAUDECODE=1)
may not change policy/access-grants.yaml — the file is read from HEAD, so the commit is what
makes a grant count. Exercises the REAL pre-commit / pre-merge-commit hooks that
`git.sh install-hooks` writes; the operator's commit (no CLAUDECODE) still works.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5031_grant_file_commit_guard.yaml`*
*Last verified: 2026-11-13*
