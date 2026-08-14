# git_identity_check

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/git_identity_check.bats`

## What It Does

T-2883 — "can this machine commit?" must be answered the way git answers it.
Six surfaces asked that question by reading `git config user.email` /
`user.name`. That read misses identity supplied through the environment, which
is how CI, cron and dispatch workers supply it — so the framework told machines
whose commits succeed that their commits would fail.
Measured before the fix: GIT_AUTHOR_*/GIT_COMMITTER_* set, no config →
`fw doctor` printed "commits will fail", `git commit` returned RC=0.
This suite holds BOTH directions. "Stop warning" would satisfy the false-positive
leg on its own, so every no-warning assertion is paired with a warning one in the
state that genuinely cannot commit.

---
*Auto-generated from Component Fabric. Card: `tests-unit-git_identity_check.yaml`*
*Last verified: 2026-08-09*
