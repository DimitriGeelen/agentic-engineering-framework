# worktree

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/worktree.sh`

## What It Does

lib/worktree.sh — fw worktree topology observability.
T-2466 (T-2464 GO Candidate C, slice 2). Read-only. `fw worktree status [--json]`
reports the git-worktree topology of the framework checkout:
- which branch the MAIN checkout is on, and whether it is master. The framework's
hooks are wired by MAIN's absolute path, so a fix only goes LIVE on this host when
MAIN's checked-out branch contains it — merging to master alone does NOT change the
on-disk hook here while main sits on a session branch.
- which worktree (if any) holds `master` checked out: while a worktree locks master,
`git checkout master` in main fails — you must `git push origin <branch>:master`.
- per-worktree merged-into-master? and live-on-this-host? state.

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `lib-worktree.yaml`*
*Last verified: 2026-06-23*
