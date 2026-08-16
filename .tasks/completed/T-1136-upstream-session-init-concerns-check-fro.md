---
id: T-1136
name: "Upstream session-init concerns check from 010-termlink — warn about open gaps
  at session start"
description: >
  Inception: Upstream session-init concerns check from 010-termlink — warn about open
  gaps at session start

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-12T09:18:11Z
last_update: '2026-08-16T22:24:23Z'
date_finished: 2026-04-12T11:03:54Z
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
  - ts: '2026-08-16T22:24:23Z'
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

# T-1136: Upstream session-init concerns check from 010-termlink — warn about open gaps at session start

## Problem Statement

010-termlink independently implemented a session-init concerns check (P-016 patch-delivery). On `fw context init`, the agent reads `concerns.yaml` and displays open (non-closed) gaps with ID, title, and age. This prevents cross-session failure blindness -- agents starting a new session don't know what gaps are open unless they explicitly check.

Currently `fw context init` shows: session ID, cron audit status, and little else. Open concerns are invisible until you run `fw gaps`. The patch adds concern awareness at session start.

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Exploration Plan

1. Check current `fw context init` output — what's shown today (DONE)
2. Verify concerns.yaml is available at init time (DONE — yes, project-level file)
3. Evaluate the proposed implementation approach (python3 YAML parsing)

## Scope Fence

**IN:** Evaluate and upstream the concerns-at-init patch.
**OUT:** Implementing — separate build task after GO.

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
- concerns.yaml exists at init time (CONFIRMED)
- Implementation is non-intrusive (additive output, no behavior change)
- Uses portable python3 YAML parsing (no new dependencies)

**NO-GO if:**
- Init output is already too verbose (would add noise)
- Concern display causes confusion for agents (false alarm on known gaps)

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO

**Rationale:** Low-risk, high-value addition. Open concerns are currently invisible at session start -- agents must explicitly run `fw gaps`. Showing them at init prevents cross-session failure blindness. The patch from 010-termlink uses python3 YAML parsing (portable, no new deps), is silent when all concerns are closed (backward compatible), and adds ~15 lines to init.sh.

**Evidence:**
- Current init shows: session ID, cron audit status -- no concern awareness
- concerns.yaml has 24 watching entries -- agents starting sessions don't see them
- Patch is non-intrusive: additive output only, silent when no open concerns
- Origin: T-283 GO decision (Option B: cross-session failure register)

## Decisions

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: Low-risk, high-value addition. Open concerns are currently invisible at session start -- agents must explicitly run `fw gaps`. Showing them at init prevents cross-ses...

**Date**: 2026-04-12T11:03:54Z
## Decision

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: Low-risk, high-value addition. Open concerns are currently invisible at session start -- agents must explicitly run `fw gaps`. Showing them at init prevents cross-ses...

**Date**: 2026-04-12T11:03:54Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-12T09:18:32Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T11:03:54Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Low-risk, high-value addition. Open concerns are currently invisible at session start -- agents must explicitly run `fw gaps`. Showing them at init prevents cross-ses...

### 2026-04-12T11:03:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-77f8f2e6
- **Timestamp:** 2026-06-02T14:55:24Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
