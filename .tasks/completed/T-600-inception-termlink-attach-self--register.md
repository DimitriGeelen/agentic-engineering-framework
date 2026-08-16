---
id: T-600
name: "Inception: TermLink attach-self — register an existing shell session as a TermLink
  endpoint for bidirectional cross-machine agent communication"
description: >
  Use case: agent on remote machine (SSH) needs to be reachable by local agent. Currently
  TermLink sessions can connect outward but not be connected to. Need a command like
  'termlink attach-self' or 'fw termlink attach' that wraps the current shell/console
  in a TermLink session, making it discoverable via hub. This enables bidirectional
  agent-to-agent communication across machines: remote agent registers itself, local
  agent connects via hub, both can send/receive. Explore TermLink register + hub start
  as building blocks.

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-24T09:06:05Z
last_update: '2026-08-16T22:25:35Z'
date_finished: 2026-03-28T17:07:13Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:25Z'
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
  - ts: '2026-08-16T22:25:35Z'
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

# T-600: Inception: TermLink attach-self — register an existing shell session as a TermLink endpoint for bidirectional cross-machine agent communication

## Problem Statement

Remote agents need to be reachable via TermLink. **Key finding:** `termlink register --self` already exists. Cross-machine requires hub (T-598, deferred).

## Assumptions

- A1: TermLink can register existing shells (VALIDATED — --self and --shell flags exist)
- A2: Cross-machine discovery works (NOT VALIDATED — requires hub)
- A3: Event communication works across sessions (VALIDATED — same-machine proven)
- A4: Auto-cleanup on exit needed (VALID — orphaned registrations pollute discovery)

## Exploration Plan

1. Check attach-self capability (done — --self flag exists)
2. Evaluate cross-machine needs (done — hub needed, not deployed)
3. Assess integration needs (done — fw wrapper, cleanup, SSH)
4. Make recommendation (done — DEFER)

## Technical Constraints

- Cross-machine requires hub deployment (T-598 prerequisite)
- Remote machine must have TermLink installed
- Self-registered sessions need deregistration trap

## Scope Fence

**IN:** Whether attach-self is feasible and valuable.
**OUT:** Building wrapper. Hub deployment. Cross-machine testing.

## Acceptance Criteria

### Agent
- [x] Problem statement validated (primitives exist, hub missing)
- [x] Assumptions tested (4 — 2 validated, 1 not validated, 1 valid)
- [x] Go/No-Go recommendation made (DEFER)

### Human
- [x] [REVIEW] Review and confirm defer
  **Steps:**
  1. Read `docs/reports/T-600-termlink-attach-self.md`
  2. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-600 no-go --rationale "your rationale"`
  **Expected:** Decision recorded
  **If not:** Discuss concerns

## Go/No-Go Criteria

**GO if:** Hub deployed, 3+ machines, proven use case
**NO-GO/DEFER if:** Hub not deployed, limited value, only 2 machines

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Recommendation

**Recommendation:** GO
**Rationale:** wan this

## Decisions

**Decision**: GO

**Rationale**: wan this

**Date**: 2026-03-28T17:07:13Z
## Decision

**Decision**: GO

**Rationale**: wan this

**Date**: 2026-03-28T17:07:13Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-24T09:09:48Z — status-update [task-update-agent]
- **Change:** horizon: next → later

### 2026-03-28 — inception-research [agent]
- **Research artifact:** docs/reports/T-600-termlink-attach-self.md
- **Key finding:** `termlink register --self` already exists — no TermLink code needed
- **Recommendation:** DEFER — blocked on hub deployment (T-598)

### 2026-03-28T10:43:47Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-28T17:07:13Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** wan this

### 2026-03-28T17:07:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4f2f1c4a
- **Timestamp:** 2026-06-02T15:03:49Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
