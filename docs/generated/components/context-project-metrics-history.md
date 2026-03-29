# metrics-history

> Historical metrics snapshots tracking task completion rates, commit velocity, and project health over time.

**Type:** data | **Subsystem:** context-fabric | **Location:** `.context/project/metrics-history.yaml`

**Tags:** `context`, `project-memory`

## What It Does

Time-series metrics history
Auto-appended by audit.sh on each run
30-day rolling retention

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `agents/audit/audit.sh` | read_by |
| `metrics.sh` | read_by |

## Related

### Tasks
- T-546: Continue fixing TermLink release builds
- T-596: Fix context budget thresholds — Anthropic reduced window to 200K without notice

---
*Auto-generated from Component Fabric. Card: `context-project-metrics-history.yaml`*
*Last verified: 2026-03-04*
