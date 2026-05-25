# metrics-history

> Historical metrics snapshots tracking task completion rates, commit velocity, and project health over time.

**Type:** data | **Subsystem:** context-fabric | **Location:** `.context/project/metrics-history.yaml`

**Tags:** `context`, `project-memory`

## What It Does

Time-series metrics history
Auto-appended by audit.sh on each run
30-day rolling retention

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | read_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| `metrics.sh` | read_by | — |
| [audit_null_timestamp](/docs/generated/tests-unit-audit_null_timestamp) | read_by | Regression test — audit.sh METRICS_EOF heredoc must not crash when .context/project/metrics-history.yaml contains a null timestamp. Origin: handover S-2026-0423-1623 AttributeError: 'NoneType' at <stdin>:108. |

## Related

### Tasks
- T-825: Timeline token usage — show per-session token costs in Watchtower /timeline
- T-847: Session housekeeping — memory updates and handover
- T-937: Commit pending handover checkpoints
- T-940: Commit accumulated generated docs and cron audits
- T-949: Fix fw self-test task-gate-allow failure — gate test expects exit 0, gets 2

---
*Auto-generated from Component Fabric. Card: `context-project-metrics-history.yaml`*
*Last verified: 2026-03-04*
