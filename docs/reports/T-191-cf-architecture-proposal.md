# T-191: Component Fabric — Architecture Proposal (Phase 5)

## Decision: GO

All 4 GO criteria met. See Phase 2-4 reports for full evidence chain.

## Architecture Summary

The Component Fabric is a **file-based dependency graph** stored in `.fabric/` that gives agents and humans machine-readable spatial awareness of the codebase. It answers 6 validated use cases: navigate, impact, UI identify, onboard, regress, completeness.

### Data Layer

```
.fabric/
  components/            # One YAML card per component (~100 for AEF)
  subsystems.yaml        # Subsystem groupings for onboarding
  watch-patterns.yaml    # File globs that should have cards
  summary.md             # Auto-generated compact overview (injected at session start)
```

**Component card** (unified schema):
- **Required:** id (file path), name, type, subsystem, location, tags, purpose
- **Edges:** `depends_on` list with typed edges (reads, writes, calls, triggers, extends, includes, renders, htmx). Reverse edges derived at query time.
- **Optional by type:** route (url, handler, template), interactive_elements (data-component, data-action, htmx, endpoint, effect), template_inheritance, format/schema_summary (data files)
- **Meta:** last_verified, created_by

### Agent Layer

```
agents/fabric/
  fabric.sh              # Dispatcher
  lib/register.sh        # register, scan, enrich
  lib/query.sh           # search, get, deps
  lib/traverse.sh        # impact, blast-radius
  lib/ui.sh              # ui queries
  lib/drift.sh           # drift, validate
  lib/summary.sh         # overview generation
  AGENT.md               # Intelligence guidance
```

### Integration Points

| Integration | Mechanism | When |
|------------|-----------|------|
| Session onboarding | SessionStart hook → `fw fabric overview` | Every session start |
| Blast radius | Post-commit hook → `fw fabric blast-radius HEAD` | Every commit |
| Drift detection | `fw audit` structure section | Every 30-min cron + pre-push |
| Granularity prompt | After `fw healing resolve` | After bug resolution |

### Web UI (Watchtower)

New Watchtower page: `/fabric` — visual browser for the component graph.

**Features:**
- **Subsystem overview:** Cards/tiles for each subsystem, click to expand
- **Component list:** Filterable/searchable table of all components
- **Component detail:** Full card view with clickable dependency links
- **Dependency graph:** Visual graph (nodes + edges) for a subsystem or component neighborhood
- **Impact view:** Select a component → highlight all downstream in the graph
- **Drift dashboard:** Unregistered count, orphaned count, stale edges

**Technology:** Same stack as existing Watchtower (Flask + Jinja2 + htmx). Graph rendering via a JS library (e.g., D3.js, Cytoscape.js, or simple SVG).

## Build Task Decomposition

### MVP (tasks 1-6): Navigate + Impact + Drift + Onboarding

| # | Name | Type | Deps | Sessions |
|---|------|------|------|----------|
| 1 | Create fabric agent structure (`agents/fabric/`, `fw fabric` routing) | Build | — | 0.5 |
| 2 | Implement `fw fabric register` + `scan` (card creation) | Build | 1 | 1 |
| 3 | Implement `fw fabric search` + `get` + `deps` (navigation queries) | Build | 1 | 1 |
| 4 | Implement `fw fabric impact` + `blast-radius` (graph traversal) | Build | 3 | 1-2 |
| 5 | Implement `fw fabric drift` + audit integration | Build | 3 | 1 |
| 6 | Implement `fw fabric overview` + session start injection | Build | 3 | 1 |

### Full (tasks 7-11): UI + Enrichment + Registration

| # | Name | Type | Deps | Sessions |
|---|------|------|------|----------|
| 7 | Implement `fw fabric ui` queries | Build | 3 | 0.5 |
| 8 | Post-commit blast-radius hook integration | Build | 4 | 0.5 |
| 9 | Batch-register all AEF components (~100 cards) | Build | 2 | 2-3 |
| 10 | Implement `fw fabric enrich` (AI-assisted enrichment) | Build | 2 | 1 |
| 11 | Watchtower fabric page (visual browser + dependency graph) | Build | 3,9 | 2-3 |

**Total: 11-14 sessions.** MVP in 5-6 sessions.

## Refined Schema (applied from Phase 3 findings)

Changes from prototype:
1. **File path as ID** — no more C-XXX numbering
2. **Single-direction edges** — `depends_on` only, reverse derived
3. **Sub-component refs** — `audit.sh#yaml-validation` for sections within files
4. **Unified schema** — one format, optional sections by type
