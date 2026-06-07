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

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| `gh` | calls | — |
| `git` | calls | — |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| `.context/cron-registry.yaml` | triggers | — |

---
*Auto-generated from Component Fabric. Card: `lib-release.yaml`*
*Last verified: 2026-04-14*
