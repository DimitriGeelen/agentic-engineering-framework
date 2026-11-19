# inception

> Watchtower UI page: Inception

**Type:** template | **Subsystem:** watchtower | **Location:** `web/templates/inception.html`

## What It Does

### Framework Reference

When the active task has `workflow_type: inception`:
1. **State the phase** — Say "This is an inception/exploration task" before doing any work
2. **Present the filled template** for review before executing any spikes or prototypes
   - **The recommendation reads `EXPLORING` while you explore (T-5226).** File with a rationale and no verdict (`fw inception start "<question>" --rationale "…"`); agent filings default to `EXPLORING`, meaning *not ready for decision*. While it reads EXPLORING, `fw task review`, `fw task review-batch` and `fw inception decide` refuse the inception, and the Watchtowe

*(truncated — see CLAUDE.md for full section)*

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [inception](/docs/generated/web-blueprints-inception) | rendered_by | Blueprint 'inception' — routes: /inception |

## Related

### Tasks
- T-959: Batch inception review page in Watchtower — surface pending go/no-go decisions with summaries (T-954 Phase 3a)

---
*Auto-generated from Component Fabric. Card: `web-templates-inception.yaml`*
*Last verified: 2026-02-20*
