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
- T-546: Continue fixing TermLink release builds
- T-588: Declarative status transition rules — compiled ACL pattern for task state machine
- T-596: Fix context budget thresholds — Anthropic reduced window to 200K without notice
- T-598: Inception: Bridge fw dispatch to TermLink file/remote — replace SSH text pipe with native hub routing and file transfer
- T-649: Horizon triage + automated Human AC validation across work-completed tasks

---
*Auto-generated from Component Fabric. Card: `budget-status.yaml`*
*Last verified: 2026-02-20*
