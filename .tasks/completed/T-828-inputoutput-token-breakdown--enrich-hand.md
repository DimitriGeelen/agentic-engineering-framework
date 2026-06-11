---
id: T-828
name: "Input/output token breakdown — enrich handover frontmatter and timeline with
  per-category token counts"
description: >
  Inception: Input/output token breakdown — enrich handover frontmatter and timeline
  with per-category token counts

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-03T23:47:45Z
last_update: '2026-06-11T22:24:30Z'
date_finished: 2026-04-03T23:53:36Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:30Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-828: Input/output token breakdown — enrich handover frontmatter and timeline with per-category token counts

## Problem Statement

Token usage in handover frontmatter is a single cumulative string ("809.7M tokens, 6608 turns"). Pricing varies ~50x across categories (cache read $0.30/MTok vs output $15/MTok), so the aggregate hides the most actionable cost signal. Should we enrich handovers with per-category token counts?

## Assumptions

1. `costs_main current` output format is stable (framework-internal, controlled by us)
2. Numeric token counts fit in YAML integers (max observed: 800M — fits fine)
3. Historical handovers without breakdown fields degrade gracefully to total-only display

## Exploration Plan

1. Check data source: does handover.sh already extract breakdown? (done — yes, partially: line 300-308)
2. Evaluate 3 options: enrich frontmatter vs read JSONL vs separate YAML (done — see research artifact)
3. Assess rendering impact (trivial — 4 extra YAML fields per session)

## Technical Constraints

None — display-only change extending existing data pipeline, no new dependencies.

## Scope Fence

**IN:** Add input/cache_read/cache_create/output to handover frontmatter; display in timeline
**OUT:** Cost calculation ($), historical backfill, sparklines, aggregation charts

## Acceptance Criteria

### Agent
- [x] Problem statement validated — pricing varies 50x across token categories
- [x] Assumptions tested — handover.sh already calls costs_main current, extracts partial data
- [x] Recommendation written: GO — Option A (enrich handover frontmatter, ~30 lines across 3 files)

### Human
- [x] [REVIEW] Review findings and approve go/no-go decision
  **Steps:**
  1. Read the research artifact: `cd /opt/999-Agentic-Engineering-Framework && cat docs/reports/T-828-token-breakdown-inception.md`
  2. Evaluate: does input/output breakdown add cost visibility value?
  3. Decide: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-828 go --rationale "your rationale"`
  **Expected:** Decision recorded
  **If not:** Ask for clarification

## Go/No-Go Criteria

**GO if:**
- Data source already exists (confirmed: handover.sh already calls costs_main current)
- Implementation is <1 hour (confirmed: ~30 lines across 3 files)
- Adds actionable cost signal (confirmed: 50x price difference between categories)

**NO-GO if:**
- Data quality is poor or inconsistent
- Timeline rendering becomes too slow

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: adds actionable cost signal

**Date**: 2026-04-03T23:53:36Z

## Recommendation

**GO — Option A** (enrich handover frontmatter). Lowest effort (~30 lines across 3 files), data source already available, natural extension of existing token_usage field. See `docs/reports/T-828-token-breakdown-inception.md` for full analysis of 3 options.

## Decision

**Decision**: GO

**Rationale**: adds actionable cost signal

**Date**: 2026-04-03T23:53:36Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-03T23:48:50Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-03T23:53:36Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** adds actionable cost signal

### 2026-04-03T23:53:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-12T09:27:23Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e47409a8
- **Timestamp:** 2026-06-02T15:05:06Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
