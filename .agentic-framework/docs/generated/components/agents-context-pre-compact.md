# pre-compact

> Pre-Compaction Hook — Save structured context before lossy compaction

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/pre-compact.sh`

## What It Does

Pre-Compaction Hook — Save structured context before lossy compaction
Fires on PreCompact — manual /compact only (auto-compaction disabled per D-027).
Generates a handover so that SessionStart:compact can
reinject structured context into the fresh session.
Part of: T-111 (Autonomous compact-resume lifecycle)
Updated: T-175 (D-028 — single handover, no emergency distinction)
Updated: T-177 (manual-only cleanup, D-027 documentation)

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `agents/handover/handover.sh` | calls |

---
*Auto-generated from Component Fabric. Card: `agents-context-pre-compact.yaml`*
*Last verified: 2026-02-20*
