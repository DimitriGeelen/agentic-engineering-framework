# test_git_hooks

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/governance/test_git_hooks.bats`

## What It Does

T-1607 (T-1601 GO follow-up, Phase 2): red-team harness for git hooks.
Phase 1 (T-1606, tests/governance/test_pretooluse_gates.bats) covered the 7
PreToolUse hooks. Phase 2 covers the git-hook layer of governance:
- commit-msg → blocks commits missing `T-XXX` reference
- pre-push → rejects lightweight tag pushes (T-1593)
- pre-push → blocks audit FAIL severity
VERSION monotonicity (4th git hook) is already pinned by
tests/unit/pre_push_version_monotonicity.bats (T-1603) — not duplicated here.
Pattern (copied from T-1603's pre_push_version_monotonicity.bats):
1. Spin a fresh temp git repo with mktemp

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `C-004` | calls |
| `C-004` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-governance-test_git_hooks.yaml`*
*Last verified: 2026-04-29*
