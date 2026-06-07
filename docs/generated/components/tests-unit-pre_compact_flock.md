# pre_compact_flock

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/pre_compact_flock.bats`

## What It Does

T-1476 — pre-compact.sh acquires a flock to prevent dual handover commits
when both user-level and project-level PreCompact hooks fire (OBS-023).

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [pre-compact](/docs/generated/agents-context-pre-compact) | calls | Pre-Compaction Hook — Save structured context before lossy compaction |
| [pre-compact](/docs/generated/agents-context-pre-compact) | tests | Pre-Compaction Hook — Save structured context before lossy compaction |

---
*Auto-generated from Component Fabric. Card: `tests-unit-pre_compact_flock.yaml`*
*Last verified: 2026-04-25*
