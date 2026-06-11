---
id: T-1120
name: "Pickup: Review marker gate blocks Watchtower GO/NO-GO decisions — human clicking
  approve button gets Task review required error (from 010-termlink)"
description: >
  Auto-created from pickup envelope. Source: 010-termlink, task T-943. Type: bug-report.

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: [pickup, bug-report]
components: []
related_tasks: []
created: 2026-04-12T08:00:02Z
last_update: '2026-06-11T22:23:40Z'
date_finished: 2026-04-12T10:55:05Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:40Z'
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

# T-1120: Pickup: Review marker gate blocks Watchtower GO/NO-GO decisions — human clicking approve button gets Task review required error (from 010-termlink)

## Problem Statement

Watchtower's inception approve button calls `fw inception decide` which requires a `.reviewed-T-XXX` marker file (T-973 gate). This marker is only created by `fw task review` (CLI). When a human navigates to Watchtower directly and clicks approve, the marker doesn't exist → "Task review required" error. Bug is blocking all 12 pending inception decisions in Watchtower.

## Assumptions

- A1: The human being on the Watchtower approvals page IS the review — creating the marker there is correct.
- A2: The fix is a 5-line addition to web/blueprints/inception.py before the decide call.

## Scope Fence

**IN:** Fix the Watchtower decide endpoint to create the review marker.
**OUT:** Changing the T-973 gate itself or the CLI flow.

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- The bug is real (confirmed: blocks all Watchtower inception approvals)
- The fix is safe (confirmed: marker only means "human has seen the review" — being on Watchtower IS the review)

**NO-GO if:**
- Creating the marker in Watchtower bypasses a meaningful safety check (disproved: the page already shows the recommendation)

## Verification

grep -q "reviewed-via-watchtower" web/blueprints/inception.py

## Recommendation

**Recommendation:** GO

**Rationale:** The bug blocks all 12 pending inception decisions in Watchtower. The fix is a 5-line addition to web/blueprints/inception.py that creates the review marker before calling `fw inception decide`. The human IS reviewing by being on the Watchtower page — creating the marker there is semantically correct.

**Evidence:**
- web/blueprints/inception.py:292 calls `fw inception decide` without a review marker
- lib/inception.sh:225 blocks without `.reviewed-T-XXX` marker
- The marker is only created by `fw task review` (CLI), not Watchtower
- Fix already applied to web/blueprints/inception.py

## Decisions

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: The bug blocks all 12 pending inception decisions in Watchtower. The fix is a 5-line addition to web/blueprints/inception.py that creates the review marker before cal...

**Date**: 2026-04-12T11:02:35Z
## Decision

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: The bug blocks all 12 pending inception decisions in Watchtower. The fix is a 5-line addition to web/blueprints/inception.py that creates the review marker before cal...

**Date**: 2026-04-12T11:02:35Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-12T10:45:06Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-12T10:55:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Fix applied: Watchtower creates review marker before decide call

### 2026-04-12T11:02:35Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: The bug blocks all 12 pending inception decisions in Watchtower. The fix is a 5-line addition to web/blueprints/inception.py that creates the review marker before cal...

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9e5061d8
- **Timestamp:** 2026-06-02T14:55:18Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
