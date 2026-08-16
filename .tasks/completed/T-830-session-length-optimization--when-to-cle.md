---
id: T-830
name: "Session length optimization — when to /clear vs continue, context cost vs momentum
  tradeoff"
description: >
  Inception: Session length optimization — when to /clear vs continue, context cost
  vs momentum tradeoff

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-04T07:58:00Z
last_update: '2026-08-16T22:25:41Z'
date_finished: 2026-04-04T09:04:01Z
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
  - ts: '2026-08-16T22:25:41Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-830: Session length optimization — when to /clear vs continue, context cost vs momentum tradeoff

## Problem Statement

Should we use `/clear` proactively to improve agent quality and reduce wasted tokens? Token analysis shows /clear costs ~745K tokens overhead per clear, but quality degradation in long sessions (instruction drift, stale context, repetition loops) may waste millions more. Need measurements to decide empirically.

## Assumptions

1. Quality degrades in long sessions (anecdotal, needs measurement)
2. Handover fidelity is sufficient to recover within 8 turns
3. Context pollution (stale tool results, superseded code) affects agent output quality
4. Efficiency metrics are meaningful proxies for quality
5. 10 sessions per group is sufficient for statistical signal

## Exploration Plan

Multi-agent TermLink inception:
1. **Agent A — Historical analysis**: Mine JSONL transcripts for error/retry patterns across session ages
2. **Agent B — Quality metrics design**: Design measurable quality indicators and propose instrumentation
3. **Agent C — Literature/best practices**: Research LLM context window management strategies
4. Synthesize findings into recommendation with measurement plan

## Technical Constraints

None — research/analysis task, no code changes in this inception.

## Scope Fence

**IN:** Evaluate /clear value proposition, design measurement framework, propose experiment
**OUT:** Implementing the measurements, running the A/B experiment, building tooling

## Acceptance Criteria

### Agent
- [x] Token cost analysis complete — /clear costs ~745K tokens overhead per clear
- [x] Quality hypothesis documented — bathtub curve finding contradicts degradation hypothesis
- [x] Historical session data mined — 14 JSONL transcripts, 472 handovers, 766 episodics (Agent A)
- [x] Measurement framework designed — 14 metrics in 4 categories with A/B experiment (Agent B)
- [x] Recommendation written — GO for measurement infrastructure, defer /clear decision to data

### Human
- [x] [REVIEW] Review findings and approve measurement implementation
  **Steps:**
  1. Read research artifact: `cd /opt/999-Agentic-Engineering-Framework && cat docs/reports/T-830-session-length-optimization.md`
  2. Evaluate proposed metrics and experiment design
  3. Decide: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-830 go --rationale "your rationale"`
  **Expected:** Decision recorded
  **If not:** Ask for clarification

## Go/No-Go Criteria

**GO if:**
- Measurement framework is concrete and implementable
- Quality signals from historical data suggest /clear has value
- Proposed metrics are actionable (not just theoretical)

**NO-GO if:**
- Historical data shows no quality difference between short and long sessions
- Proposed measurements are too expensive or invasive to implement

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Recommendation

**Recommendation:** GO
**Rationale:** build measurement infrastructure

## Decisions

**Decision**: GO

**Rationale**: build measurement infrastructure

**Date**: 2026-04-04T09:04:01Z
## Decision

**Decision**: GO

**Rationale**: build measurement infrastructure

**Date**: 2026-04-04T09:04:01Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-04T07:58:23Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-04T09:04:01Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** build measurement infrastructure

### 2026-04-04T09:04:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-12T09:27:23Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-459ace4b
- **Timestamp:** 2026-06-02T15:05:07Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
