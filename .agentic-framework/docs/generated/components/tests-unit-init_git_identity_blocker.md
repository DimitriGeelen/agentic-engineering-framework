# init_git_identity_blocker

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/init_git_identity_blocker.bats`

## What It Does

T-2818 / OBS-170 — `fw init` must not sign off a project that cannot commit.
A machine with no git identity makes `git commit` die RC=128 "Author identity
unknown" *before any framework hook runs*, so onboarding task T-003 ("First
governed commit") is impossible. This is not a hypothetical fresh-machine state:
the host this was found on has no global identity at all — the framework repo
works only because it carries a repo-local one, so every project `fw init`
created there inherited the failure.
The condition was already warned about three times (init line ~4 of ~120, the
git-identity inheritance block, and `fw doctor`). What made it invisible is that
every line printed AFTER the warning contradicted it: "Validation passed: 43/44",

---
*Auto-generated from Component Fabric. Card: `tests-unit-init_git_identity_blocker.yaml`*
*Last verified: 2026-08-05*
