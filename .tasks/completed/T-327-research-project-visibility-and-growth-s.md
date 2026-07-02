---
id: T-327
name: "Research project visibility and growth strategy"
description: >
  5-agent parallel research into how to increase visibility of the Agentic Engineering
  Framework. Covers GitHub discoverability, content marketing, community building,
  ecosystem positioning, and launch strategy.

status: work-completed
workflow_type: inception
owner: claude
horizon: null
components: []
related_tasks: []
created: 2026-03-05T01:03:59Z
last_update: '2026-06-11T22:24:18Z'
date_finished: 2026-03-05T01:12:12Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:18Z'
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

# T-327: Research project visibility and growth strategy

## Problem Statement

The Agentic Engineering Framework has no external visibility. It's a mature project (325+ tasks, 12 subsystems, 126 components) that occupies an uncontested "AI Agent Governance" category, but zero external users know it exists. The 2026 market timing is ideal — industry narrative shifted from "AI writes code fast" to "but is it safe?"

## Assumptions

1. The "AI Agent Governance" category is unoccupied — **validated** (5-agent competitive scan found no direct competitors)
2. Developers are searching for solutions to AI agent safety/traceability — **validated** (high-volume search terms: "Claude Code best practices", "AI agent guardrails")
3. The project is ready for external users — **partially validated** (README rewritten T-326, but install flow needs testing on fresh machines)

## Exploration Plan

5 parallel research agents covering:
1. GitHub discoverability (SEO, topics, awesome lists, features)
2. Content marketing (blog platforms, article topics, social media, video)
3. Community building (platforms, contributor onboarding, docs, partnerships)
4. Ecosystem positioning (package managers, marketplaces, SEO, integrations)
5. Launch strategy (HN, Product Hunt, Reddit, newsletters, conferences)

All completed. Synthesized to `docs/reports/T-327-visibility-strategy.md`.

## Technical Constraints

None — this is a marketing/distribution research task, not a technical build.

## Scope Fence

**IN:** Research and strategy for increasing project visibility. Creating build tasks for execution.
**OUT:** Actually executing the strategy (separate build tasks).

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Unoccupied category confirmed (yes — "AI Agent Governance")
- Clear action plan with quick wins under 2 hrs (yes — 5 actions under 1 hr total)
- Timing aligned with market narrative (yes — 2026 "is it safe?" narrative)

**NO-GO if:**
- Saturated market with established competitors (no — no direct competitors found)
- Project not ready for external users (partially — README done, install needs testing)

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: 5-agent research confirms unoccupied AI Agent Governance category, ideal timing (2026 safety narrative), clear action plan with quick wins. Proceed with phased build tasks.

**Date**: 2026-03-05T01:11:14Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-05T01:11:14Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** 5-agent research confirms unoccupied AI Agent Governance category, ideal timing (2026 safety narrative), clear action plan with quick wins. Proceed with phased build tasks.

### 2026-03-05T01:12:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b78aa85e
- **Timestamp:** 2026-06-02T15:02:11Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
