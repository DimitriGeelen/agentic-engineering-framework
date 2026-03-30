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
- T-677: Fix fw init hook merge — pre-existing settings.json blocks framework hooks
- T-678: vnx-orchestration deep-dive — ingest, build fabric, analyze architecture and patterns
- T-728: Commit session state and generate episodics for completed tasks
- T-729: Final session commit — untracked files, cron audits
- T-744: Commit untracked research artifacts and clean up git state

---
*Auto-generated from Component Fabric. Card: `budget-status.yaml`*
*Last verified: 2026-02-20*
