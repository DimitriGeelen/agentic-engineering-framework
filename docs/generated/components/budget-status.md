# budget-status

> Cached budget level for fast PreToolUse decisions. Avoids re-reading JSONL transcript on every tool call.

**Type:** data | **Subsystem:** budget-management | **Location:** `.context/working/.budget-status`

**Tags:** `budget`, `state`, `cache`, `json`

## What It Does

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [budget-gate](/docs/generated/budget-gate) | read_by | Block Write/Edit/Bash tool execution when context budget reaches critical level (>=170K tokens). Primary enforcement for P-009. |
| [checkpoint](/docs/generated/checkpoint) | read_by | Post-tool budget monitoring. Warns at thresholds, auto-triggers handover at critical, detects compaction, manages inception checkpoints. |
| [checkpoint](/docs/generated/checkpoint) | writes_by | Post-tool budget monitoring. Warns at thresholds, auto-triggers handover at critical, detects compaction, manages inception checkpoints. |

## Related

### Tasks
- T-832: Fix install.sh unbound LOCAL_REPO variable in update path
- T-833: Fix install.sh SIGPIPE exit 141 — head -1 in pipe with set -e
- T-847: Session housekeeping — memory updates and handover
- T-937: Commit pending handover checkpoints
- T-938: Add more dynamic working files to .gitignore

---
*Auto-generated from Component Fabric. Card: `budget-status.yaml`*
*Last verified: 2026-02-20*
