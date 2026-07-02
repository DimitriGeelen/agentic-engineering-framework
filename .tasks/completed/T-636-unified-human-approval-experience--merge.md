---
id: T-636
name: "Unified human approval experience — merge Watchtower approvals page with fw
  task review QR/link/command into one rich flow"
description: >
  Inception: Unified human approval experience — merge Watchtower approvals page with
  fw task review QR/link/command into one rich flow

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: [lib/review.sh, web/blueprints/__init__.py, web/blueprints/review.py,
  web/templates/_review_acs.html, web/templates/review.html]
related_tasks: []
created: 2026-03-27T10:06:21Z
last_update: '2026-06-11T22:24:26Z'
date_finished: 2026-03-28T23:38:49Z
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

# T-636: Unified human approval experience — merge Watchtower approvals page with fw task review QR/link/command into one rich flow

## Problem Statement

Two great human approval mechanisms exist but are disconnected: Watchtower /approvals (web UI with buttons) and fw task review (terminal QR + link + artifacts). The human bounces between terminal and browser. Neither surface is complete alone. Research artifact: docs/reports/T-636-unified-approval-experience.md

## Assumptions

1. Human AC toggle already works in Watchtower (validated by spike 4)
2. Tier 0 flow works end-to-end CLI and Watchtower (validated by spike 1, 6 gaps found)
3. Mobile QR scan should land on a lightweight approval page (validated by spike 5)
4. Existing routes can be extended rather than creating new ones (validated by spike 3)
5. Flask dev server single-thread limits SSE — polling needed for dev mode (spike 5)

## Exploration Plan

- Spike 1: Current flow audit — 252 lines, 6 gaps found (done)
- Spike 2: Unified approval page design — 430 lines (done)
- Spike 3: Terminal-to-Watchtower bridge — 199 lines (done)
- Spike 4: Human AC checkboxes in Watchtower — 142 lines (done)
- Spike 5: Mobile/QR experience — 314 lines (done)

## Technical Constraints

- Flask dev server is single-threaded — SSE blocks, use htmx polling instead
- CSRF skipped for /api/ routes — mobile can POST without session cookies
- No authentication in Watchtower — HMAC tokens for QR security deferred to Phase 3
- Hooks snapshot at session start — check-tier0.sh changes need session restart

## Scope Fence

**IN:** Unified /approvals page, check-tier0.sh Watchtower link, Complete Task button, /review/T-XXX mobile route
**OUT:** Full auth system, SSE live updates, rejection feedback channel (Phase 3)

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested (5 spikes, 1337 lines of research)
- [x] Recommendation written with rationale (docs/reports/T-636-unified-approval-experience.md)

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read the research artifact and recommendation in this task
  2. Evaluate go/no-go criteria against findings
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-XXX go|no-go --rationale "your rationale"`
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Phase 1 (unified page + tier0 link + complete button) fits in 3 build tasks
- Existing Watchtower infrastructure supports the changes without major refactor
- Human AC toggle already works (confirmed by spike 4)

**NO-GO if:**
- Requires full auth system before any approval surface is useful
- Flask single-thread limitation makes real-time updates impossible for the use case

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: 5-agent research complete, Phase 1 fits 3 build tasks, Human AC toggle already works, high value low effort

**Date**: 2026-03-27T10:21:27Z
## Decision

**Decision**: GO

**Rationale**: 5-agent research complete, Phase 1 fits 3 build tasks, Human AC toggle already works, high value low effort

**Date**: 2026-03-27T10:21:27Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-27T10:06:42Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-27T10:21:27Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** 5-agent research complete, Phase 1 fits 3 build tasks, Human AC toggle already works, high value low effort

### 2026-03-28T23:38:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3146e74f
- **Timestamp:** 2026-06-02T15:04:02Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
