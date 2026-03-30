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
- T-744: Commit untracked research artifacts and clean up git state
- T-762: Fix remaining shellcheck warnings + unit tests for episodic, init, safe-commands libs
- T-764: Add unit tests for core libs — tasks, yaml, keylock, enums, paths
- T-777: Observation inbox migration — process pickup-051-vinix24 through pipeline
- T-788: Unit tests for remaining lib files — ask, build, harvest, init, promote, upstream, validate-init

---
*Auto-generated from Component Fabric. Card: `context-project-metrics-history.yaml`*
*Last verified: 2026-03-04*
