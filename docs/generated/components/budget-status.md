# budget-status

> Cached budget level for fast PreToolUse decisions. Avoids re-reading JSONL transcript on every tool call.

**Type:** data | **Subsystem:** budget-management | **Location:** `.context/working/.budget-status`

**Tags:** `budget`, `state`, `cache`, `json`

## What It Does

## Used By (3)

| Component | Relationship |
|-----------|-------------|
| `C-007` | read_by |
| `C-008` | read_by |
| `C-008` | writes_by |

## Related

### Tasks
- T-247: Dispatch fabric context + auto-registration — close agent blind spots
- T-277: First deployment — Watchtower to Ring20 production
- T-290: Session housekeeping — fill stale handover, commit cron rotation
- T-293: Fill stale handover and commit audit rotation
- T-324: Fix OneDev-to-GitHub cascade and exclude buildspec from GitHub

---
*Auto-generated from Component Fabric. Card: `budget-status.yaml`*
*Last verified: 2026-02-20*
