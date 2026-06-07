# upgrade_dedupe_user_hooks

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/upgrade_dedupe_user_hooks.bats`

## What It Does

T-1481 — `fw upgrade --dedupe-user-hooks` opt-in remediation. Removes
framework hooks from $HOME/.claude/settings.json that duplicate the
project-level config; always backs up first. T-1479/T-1480 surface the
overlap; this gives the user a one-command fix.

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [upgrade](/docs/generated/lib-upgrade) | calls | fw upgrade - Sync framework improvements to a consumer project |
| [upgrade](/docs/generated/lib-upgrade) | tests | fw upgrade - Sync framework improvements to a consumer project |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-upgrade_dedupe_user_hooks.yaml`*
*Last verified: 2026-04-25*
