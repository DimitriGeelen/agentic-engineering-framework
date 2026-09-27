# worktree

> lib/worktree.sh — fw worktree topology observability.

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

### Framework Reference

**The default is the main checkout. Do not create a git worktree unless the
operator has explicitly instructed one, in this session, in their own words.**

This overrides every other passage in this file. Where older text reads as
"use a worktree for parallel work" or "real code goes through a worktree", the
rule below wins.

*(truncated — see CLAUDE.md for full section)*

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [t3117_gc_landing_predicate](/docs/generated/tests-unit-t3117_gc_landing_predicate) | tests_by | T-3117: `fw worktree gc` decides "has this landed?" against the right trunk, and by the right test. |
| [enrich](/docs/generated/agents-fabric-lib-enrich) | called_by | Fabric enrichment engine — auto-detect dependency edges from source analysis. |

---
*Auto-generated from Component Fabric. Card: `lib-worktree.yaml`*
*Last verified: 2026-06-23*
