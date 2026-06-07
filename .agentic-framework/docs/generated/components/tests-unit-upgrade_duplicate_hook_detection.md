# upgrade_duplicate_hook_detection

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/upgrade_duplicate_hook_detection.bats`

## What It Does

T-1479 — fw upgrade detects when framework hooks are registered at both
user-level (~/.claude/settings.json) and project-level
(.claude/settings.json), warning the consumer (does NOT auto-remove user
state). This addresses the structural cause of OBS-023 (T-1478 mitigates
the symptom in pre-compact.sh).

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [upgrade](/docs/generated/lib-upgrade) | calls | fw upgrade - Sync framework improvements to a consumer project |
| [upgrade](/docs/generated/lib-upgrade) | tests | fw upgrade - Sync framework improvements to a consumer project |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-upgrade_duplicate_hook_detection.yaml`*
*Last verified: 2026-04-25*
