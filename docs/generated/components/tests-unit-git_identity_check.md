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

## Dependencies (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [git-identity](/docs/generated/lib-git-identity) | calls | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [git-identity](/docs/generated/lib-git-identity) | tests | TODO: describe what this component does |
| [init](/docs/generated/lib-init) | tests | fw init - Bootstrap a new project with the Agentic Engineering Framework |
| [setup](/docs/generated/lib-setup) | tests | fw setup - Guided onboarding wizard for new projects |
| [preflight](/docs/generated/lib-preflight) | tests | fw preflight subcommand. Validates system prerequisites (bash version, git version, python3, PyYAML) before framework operations. |
| [validate-init](/docs/generated/lib-validate-init) | tests | Post-init validation — reads #@init: tags from init.sh and validates each creation unit exists and is correct. Called automatically at end of fw init and available as fw validate-init. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-git_identity_check.yaml`*
*Last verified: 2026-08-09*
