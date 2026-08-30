# release

> Release tagging + GitHub Release automation (T-1256). Cuts a new annotated tag based on latest v* (patch-bumping by default), pushes to all remotes, and creates a GitHub Release via gh CLI. Idempotent — no-op when HEAD == latest tag. Entrypoint for `fw release` subcommand and weekly cron job release-weekly.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/release.sh`

**Tags:** `release`, `tagging`, `github`, `cron`

## What It Does

lib/release.sh - Release tagging + GitHub Release automation (T-1256)
Cuts a new annotated tag based on the latest v* tag (bumping patch by default),
pushes to all remotes with --follow-tags, and creates a GitHub Release if gh
is available. Idempotent: exits cleanly when there are no commits since the
latest tag.
Designed to be run from cron on a weekly schedule and manually via `fw release`.

### Framework Reference

**Development runs on `bleeding-edge`. `master` is the release train: it receives
fast-forward landings at RELEASE only, and authors nothing.**

Two branches, two jobs:

| Branch | Role | Who writes it |
|---|---|---|
| `bleeding-edge` | The sanctioned development branch. The persistent session runs here; handovers, task files, `.context/` memory and landed code all commit here. | The session, plus worktrees landing back (§Worktree Policy). |
| `master` | The **consumer install surface**. `lib/consumer-recover.sh:19` calls the GitHub remote the *canonical public mirror*, and that is what consu

*(truncated — see CLAUDE.md for full section)*

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| `gh` | calls | — |
| `git` | calls | — |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| `.context/cron-registry.yaml` | triggers | — |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `lib-release.yaml`*
*Last verified: 2026-04-14*
