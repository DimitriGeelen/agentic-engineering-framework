# arc-012-continuous-mode-live-fire

> **Purpose:** run the continuous-run loop end-to-end and observe the `headline_mechanic` firing — an agent that crosses the context-budget threshold *without operator relay*, self-checkpoints, hands over, auto-restarts via `claude-fw`…

**Type:** script | **Subsystem:** docs | **Location:** `docs/runbooks/arc-012-continuous-mode-live-fire.md`

## What It Does

Runbook: arc-012 Continuous-Mode Live-Fire Test

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [checkpoint](/docs/generated/checkpoint) | calls | Post-tool budget monitoring. Warns at thresholds, auto-triggers handover at critical, detects compaction, manages inception checkpoints. |

---
*Auto-generated from Component Fabric. Card: `docs-runbooks-arc-012-continuous-mode-live-fire.yaml`*
*Last verified: 2026-06-13*
