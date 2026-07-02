---
id: T-644
name: "Watchtower landing page refactor — summary dashboard pointing to /approvals
  as action hub"
description: >
  Inception: Watchtower landing page refactor — summary dashboard pointing to /approvals
  as action hub

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-03-27T12:30:32Z
last_update: '2026-06-11T22:24:26Z'
date_finished: 2026-03-27T12:36:56Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:26Z'
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

# T-644: Watchtower landing page refactor — summary dashboard pointing to /approvals as action hub

## Problem Statement

Three surfaces show "what needs human attention" — landing page (read-only full list), `/approvals` (interactive), `/tasks/T-XXX` (full detail). The landing page's "Awaiting Your Verification" section duplicates `/approvals` Human ACs without interactivity. Human sees same info in two places with different capabilities.

## Assumptions

1. Landing page should be a "glance dashboard" — counts + top items, not full lists
2. `/approvals` should be the ONE action hub — self-contained with full detail
3. Existing "Needs Your Decision" scan section partially overlaps with GO decisions on /approvals
4. Nav badge showing pending count would drive discovery of /approvals

## Exploration Plan

- Spike 1: Audit current landing page sections and overlap with /approvals (done — see research artifact)
- Spike 2: Design summary card replacement for "Awaiting Your Verification"

## Technical Constraints

- Landing page has two modes: cockpit (scan-driven) and fallback (no scan). Both need the change.
- Files are in `.agentic-framework/web/` (upstream framework code) — edits here affect all consumers.

## Scope Fence

**IN:** Summary card on landing page, enriched /approvals Human ACs, nav badge
**OUT:** Merging scan-driven "Needs Your Decision" with /approvals GO decisions (separate task)

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale (docs/reports/T-644-landing-page-approvals-unification.md)

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read docs/reports/T-644-landing-page-approvals-unification.md
  2. Evaluate: Does Option A (summary + link) make sense for the landing page?
  3. Approve in Watchtower at http://192.168.10.107:3000/approvals
  **Expected:** GO decision recorded, build tasks created
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Summary card pattern is cleaner than the current full list
- /approvals can be made self-contained without excessive complexity
- Nav badge is feasible within render_page() context injection

**NO-GO if:**
- Scan-driven "Needs Your Decision" conflicts with /approvals GO decisions requiring major refactor
- Landing page needs the full list for a use case /approvals can't serve

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Recommendation

**Recommendation:** GO
**Rationale:** go

## Decisions

**Decision**: GO

**Rationale**: go

**Date**: 2026-03-27T12:36:56Z
## Decision

**Decision**: GO

**Rationale**: go

**Date**: 2026-03-27T12:36:56Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-27T12:30:42Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-27T12:36:56Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** go

### 2026-03-27T12:36:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-06T22:29:19Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-14cf1e2b
- **Timestamp:** 2026-06-02T15:04:05Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
