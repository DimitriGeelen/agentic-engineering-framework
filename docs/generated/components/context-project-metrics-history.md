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
- T-777: Observation inbox migration — process pickup-051-vinix24 through pipeline
- T-788: Unit tests for remaining lib files — ask, build, harvest, init, promote, upstream, validate-init
- T-847: Session housekeeping — memory updates and handover
- T-937: Commit pending handover checkpoints
- T-940: Commit accumulated generated docs and cron audits

---
*Auto-generated from Component Fabric. Card: `context-project-metrics-history.yaml`*
*Last verified: 2026-03-04*
