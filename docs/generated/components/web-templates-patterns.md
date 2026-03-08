# patterns

> Watchtower UI page: Patterns

**Type:** template | **Subsystem:** watchtower | **Location:** `web/templates/patterns.html`

## What It Does

### Framework Reference

**Parallel Investigation** (T-059, T-061, T-086): 3-5 Explore agents scan different aspects. Each returns structured findings. Orchestrator synthesizes.

**Parallel Audit** (T-072): 3 agents review different artifact categories. Each returns pass/warn/fail summary. Combined into report.

**Parallel Enrichment** (T-073): N agents each produce one file. MUST write to disk, return only path+summary. Cap at 5 parallel. Use `fw bus post` for formal tracking.

**Sequential TDD** (T-058): Fresh agent per implementation task with review between.

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `C-003` | rendered_by |

---
*Auto-generated from Component Fabric. Card: `web-templates-patterns.yaml`*
*Last verified: 2026-02-20*
