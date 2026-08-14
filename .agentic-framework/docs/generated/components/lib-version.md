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

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [lib_version](/docs/generated/tests-unit-lib_version) | called-by | Unit tests for version (16 tests) |
| [lib_version](/docs/generated/tests-unit-lib_version) | called_by | Unit tests for version (16 tests) |
| [lib_version](/docs/generated/tests-unit-lib_version) | tests_by | Unit tests for version (16 tests) |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Related

### Tasks
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `lib-version.yaml`*
*Last verified: 2026-03-27*
