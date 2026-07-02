---
id: T-1123
name: "Pickup: Approvals page shows inception tasks without recommendations — creates
  noise, missing Go/No-Go criteria display (from 010-termlink)"
description: >
  Auto-created from pickup envelope. Source: 010-termlink, task T-944. Type: bug-report.

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-04-12T08:15:01Z
last_update: '2026-06-11T22:23:40Z'
date_finished: 2026-04-13T11:06:33Z
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

# T-1123: Pickup: Approvals page shows inception tasks without recommendations — creates noise, missing Go/No-Go criteria display (from 010-termlink)

## Problem Statement

Superseded by T-1213 (inception GO → T-1214, T-1215). This pickup from 010-termlink described the same
issue: inception cards on /approvals showing bare radio buttons without recommendations. T-1213 performed
the full RCA and produced fixes (template fallback context + `fw task review` warning).

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

## Acceptance Criteria

### Agent
- [x] Problem statement validated (superseded by T-1213)
- [x] Assumptions tested (covered by T-1213 RCA)
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
- Distinct issue not covered by T-1213

**NO-GO if:**
- Superseded by T-1213 (which it is)

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** NO-GO — superseded by T-1213.

**Rationale:** This pickup predated the full RCA (T-1213) which identified the same issue and
produced two build tasks: T-1214 (template fallback context) and T-1215 (`fw task review` warning).
Both are completed. No additional work needed.

**Evidence:**
- T-1213 GO decision: inception approvals bare cards RCA
- T-1214 completed: template shows fallback context when recommendation missing
- T-1215 completed: `fw task review` warning for inception tasks without `## Recommendation`

<!--
     - Finding 1
     - Finding 2
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

**Decision**: NO-GO

**Rationale**: Recommendation: NO-GO — superseded by T-1213.

Rationale: This pickup predated the full RCA (T-1213) which identified the same issue and
produced two build tasks: T-1214 (template fallback context) and T-1215 (`fw task review` warning).
Both are completed. No additional work needed.

Evidence:
- T-1213 GO decision: inception approvals bare cards RCA
- T-1214 completed: template shows fallback context when recommendation missing
- T-1215 completed: `fw task review` warning for inception tasks without `## Recommendation`

**Date**: 2026-04-13T11:06:33Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-12T10:58:41Z — status-update [task-update-agent]
- **Change:** horizon: next → later
- **Reason:** Covered by T-1149 — approvals page now filters tasks without recommendations

### 2026-04-13T09:53:43Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

### 2026-04-13T11:06:33Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** NO-GO
- **Rationale:** Recommendation: NO-GO — superseded by T-1213.

Rationale: This pickup predated the full RCA (T-1213) which identified the same issue and
produced two build tasks: T-1214 (template fallback context) and T-1215 (`fw task review` warning).
Both are completed. No additional work needed.

Evidence:
- T-1213 GO decision: inception approvals bare cards RCA
- T-1214 completed: template shows fallback context when recommendation missing
- T-1215 completed: `fw task review` warning for inception tasks without `## Recommendation`

### 2026-04-13T11:06:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: NO-GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a3d0f8e8
- **Timestamp:** 2026-06-02T14:55:19Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
