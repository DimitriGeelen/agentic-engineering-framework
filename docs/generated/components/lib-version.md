# version

> fw version subcommand: show framework version, git tag, commit count, paths. Supports --check for update detection.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/version.sh`

## What It Does

lib/version.sh — Version bumping, checking, and sync for the Agentic Engineering Framework
Provides:
fw version bump [major|minor|patch] [--tag] [--dry-run]
fw version check
fw version sync [--dry-run]
Single source of truth: FW_VERSION in bin/fw line 14
All other VERSION files are derived copies.
Part of: Agentic Engineering Framework (T-606)

## Related

### Tasks
- T-606: Version bumping mechanism — structural enforcement for version tracking across framework and vendored projects
- T-690: Fix self-audit false FAIL on settings.json — node output includes newline before exit code
- T-724: Sync vendor copies — T-722 settings changes to .agentic-framework
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts

---
*Auto-generated from Component Fabric. Card: `lib-version.yaml`*
*Last verified: 2026-03-27*
