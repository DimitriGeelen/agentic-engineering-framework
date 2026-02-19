---
id: T-190
name: "Investigate sub-agent research persistence — ensure agent findings are saved to docs/reports for traceability"
description: >
  Inception: Investigate sub-agent research persistence — ensure agent findings are saved to docs/reports for traceability

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
related_tasks: []
created: 2026-02-19T09:12:32Z
last_update: 2026-02-19T09:13:09Z
date_finished: null
---

# T-190: Investigate sub-agent research persistence — ensure agent findings are saved to docs/reports for traceability

## Problem Statement

When sub-agents (Explore, general-purpose) perform research during inception tasks, their findings are ephemeral — consumed by the orchestrator but NOT persisted to `docs/reports/`. This was observed in T-120 where the agent research on the Google Context Engineering whitepaper was returned as context-window content but the raw WebFetch results and agent synthesis were not automatically saved as artifacts. If the session crashes or context compacts, research that took significant tokens to produce is lost forever.

**The gap:** No structural mechanism ensures sub-agent research outputs land in `docs/reports/T-XXX-*.md` with proper frontmatter for discovery. The Sub-Agent Dispatch Protocol (CLAUDE.md) says content generators "MUST write output to disk" but this is behavioral (advisory), not structural (enforced). Evidence: `fw bus` was designed for this but has zero usage across 190 tasks (L-057).

**For:** All agents performing inception/research workflows. **Why now:** T-120/T-130 both did substantial web research that exists only in session transcripts, not in the artifact layer. As we do more inceptions, this knowledge leakage compounds.

## Assumptions

1. Sub-agent research outputs are valuable enough to persist (not all are — some are quick lookups)
2. A structural gate or convention can enforce persistence without excessive friction
3. `docs/reports/` is the right location (vs `.context/` or a new directory)

## Exploration Plan

1. **Audit existing research persistence** — scan `docs/reports/` for which inception tasks have saved research vs which don't (15 min)
2. **Identify enforcement points** — where in the dispatch/inception workflow could persistence be structurally enforced? (15 min)
3. **Evaluate approaches** — (a) sub-agent prompt template with mandatory write-to-disk, (b) post-inception hook that checks for artifacts, (c) inception completion gate requiring docs/reports/ file, (d) fw bus integration (15 min)

## Technical Constraints

None — this is a workflow/convention change, not infrastructure.

## Scope Fence

**IN:** How to ensure sub-agent research is persisted to disk with traceability (task ID, date, frontmatter)
**OUT:** Changing how sub-agents are dispatched, modifying the Task tool itself, building a search/indexing system for research docs

## Acceptance Criteria

- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- A bounded, low-friction mechanism exists to enforce research persistence
- Evidence of >3 inception tasks with lost/unperisted research

**NO-GO if:**
- All inception research is already adequately persisted
- Enforcement would add significant friction to the inception workflow

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
