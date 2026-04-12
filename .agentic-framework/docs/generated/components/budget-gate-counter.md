# budget-gate-counter

> Text integer tracking tool invocation count between budget rechecks. Read by budget-gate to decide when to re-read the transcript.

**Type:** data | **Subsystem:** budget-management | **Location:** `.context/working/.budget-gate-counter`

**Tags:** `budget`, `counter`, `state`, `working-memory`

## What It Does

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `budget-gate` | reads |

## Related

### Tasks
- T-816: Null object fallback for hooks — fail-open resilience pattern
- T-817: 3-tier config resolution — env var configuration layer for framework settings
- T-847: Session housekeeping — memory updates and handover
- T-937: Commit pending handover checkpoints
- T-938: Add more dynamic working files to .gitignore

---
*Auto-generated from Component Fabric. Card: `budget-gate-counter.yaml`*
*Last verified: 2026-02-21*
