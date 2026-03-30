# version

> TODO: describe what this component does

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

---
*Auto-generated from Component Fabric. Card: `lib-version.yaml`*
*Last verified: 2026-03-27*
