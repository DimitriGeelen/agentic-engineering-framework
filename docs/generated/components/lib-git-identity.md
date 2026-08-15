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

---
*Auto-generated from Component Fabric. Card: `lib-git-identity.yaml`*
*Last verified: 2026-08-09*
