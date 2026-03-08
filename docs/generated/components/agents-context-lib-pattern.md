# pattern

> Context Agent - add-pattern command

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/lib/pattern.sh`

## What It Does

Context Agent - add-pattern command
Add a pattern to project memory

### Framework Reference

**Parallel Investigation** (T-059, T-061, T-086): 3-5 Explore agents scan different aspects. Each returns structured findings. Orchestrator synthesizes.

**Parallel Audit** (T-072): 3 agents review different artifact categories. Each returns pass/warn/fail summary. Combined into report.

**Parallel Enrichment** (T-073): N agents each produce one file. MUST write to disk, return only path+summary. Cap at 5 parallel. Use `fw bus post` for formal tracking.

**Sequential TDD** (T-058): Fresh agent per implementation task with review between.

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `C-001` | called_by |

## Documentation

- [Deep Dive: Three-Layer Memory](docs/articles/deep-dives/04-three-layer-memory.md) (deep-dive)

## Related

### Tasks
- T-166: Implement governance inheritance in fw init — seed practices, decisions, and patterns
- T-348: Fix update-task.sh sed failing on macOS BSD sed

---
*Auto-generated from Component Fabric. Card: `agents-context-lib-pattern.yaml`*
*Last verified: 2026-02-20*
