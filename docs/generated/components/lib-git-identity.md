# git-identity

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/git-identity.sh`

## What It Does

lib/git-identity.sh — one answer to "can this machine commit?" (T-2883)
Six surfaces used to ask this question and each asked it slightly differently,
all of them by reading `git config user.email` / `user.name`. That probe is
wrong in one direction and the direction matters: it misses identity supplied
through the environment, which is exactly how CI, cron and dispatch workers
supply it. Measured 2026-08-09 — with GIT_AUTHOR_*/GIT_COMMITTER_* set and no
config, `fw doctor` said "commits will fail" and the commit landed RC=0.
A warning that fires when nothing is wrong stops carrying information (L-527),
and this one fired on every automated run.
`git var GIT_COMMITTER_IDENT` is the authoritative probe because it is the same

## Used By (9)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [termlink](/docs/generated/agents-termlink-termlink) | called_by | TermLink integration wrapper: spawn, exec, dispatch, cleanup, status. Adds task-tagging and budget checks around the termlink binary. |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [git_identity_check](/docs/generated/tests-unit-git_identity_check) | called_by | TODO: describe what this component does |
| [git_identity_check](/docs/generated/tests-unit-git_identity_check) | tests_by | TODO: describe what this component does |
| [git_worker_commits](/docs/generated/tests-unit-git_worker_commits) | tests_by | TODO: describe what this component does |
| [init](/docs/generated/lib-init) | called_by | fw init - Bootstrap a new project with the Agentic Engineering Framework |
| [preflight](/docs/generated/lib-preflight) | called_by | fw preflight subcommand. Validates system prerequisites (bash version, git version, python3, PyYAML) before framework operations. |
| [setup](/docs/generated/lib-setup) | called_by | fw setup - Guided onboarding wizard for new projects |
| [validate-init](/docs/generated/lib-validate-init) | called_by | Post-init validation — reads #@init: tags from init.sh and validates each creation unit exists and is correct. Called automatically at end of fw init and available as fw validate-init. |

---
*Auto-generated from Component Fabric. Card: `lib-git-identity.yaml`*
*Last verified: 2026-08-09*
