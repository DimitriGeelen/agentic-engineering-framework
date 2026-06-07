---
id: T-704
name: "DAG federation for cross-machine knowledge graphs"
description: >
  Cross-machine knowledge graphs without central coordination. Relevant for TermLink
  multi-agent. Score: 18/20 (D1:4 D2:5 D3:4 D4:5). Source: T-697 pattern harvest #9.

status: captured
workflow_type: inception
owner: human
horizon: later
tags: [federation, kcp-pattern]
components: []
related_tasks: []
created: 2026-03-29T08:58:02Z
last_update: '2026-06-05T18:00:04Z'
date_finished:
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 4
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=4 (body:cross-machine)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T20:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 4
      F1: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=4 (body:cross-machine); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 4
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=4 (body:cross-machine); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-29T23:00:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 4
      F1: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=4 (body:cross-machine); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-01T08:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 4
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=4 (body:cross-machine)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-02T08:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=4 (body:cross-machine); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-05T18:00:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-05T18:00:04Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-704: DAG federation for cross-machine knowledge graphs

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

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
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

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
- Root cause identified with bounded fix
- Fix is scoped and testable

**NO-GO if:**
- Root cause identified with bounded fix
- Fix is scoped and testable

## Recommendation

**Recommendation:** DEFER — speculative pattern harvest, no current need.

**Rationale:** Captured from T-697 pattern harvest (KCP pattern #9) as a "potentially relevant for TermLink multi-agent" note. No concrete cross-machine knowledge graph problem exists today — TermLink handles its own cross-machine coordination via hub/secret and the framework uses per-project isolation. Re-evaluate when: (a) cross-machine knowledge sharing becomes a friction point, or (b) a concrete multi-agent federation use case emerges.

**Evidence:**
- Source: T-697 pattern harvest (captured, not applied)
- Horizon: later (correctly parked)
- No active federation scenario — framework uses pickup envelopes + TermLink remote for cross-machine today

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

**Decision**: DEFER

**Rationale**: Recommendation: DEFER — speculative pattern harvest, no current need.

Rationale: Captured from T-697 pattern harvest (KCP pattern #9) as a "potentially relevant for TermLink multi-agent" note. No concrete cross-machine knowledge graph problem exists today — TermLink handles its own cross-machine coordination via hub/secret and the framework uses per-project isolation. Re-evaluate when: (a) cross-machine knowledge sharing becomes a friction point, or (b) a concrete multi-agent federation use case emerges.

Evidence:
- Source: T-697 pattern harvest (captured, not applied)
- Horizon: later (correctly parked)
- No active federation scenario — framework uses pickup envelopes + TermLink remote for cross-machine today

**Date**: 2026-04-24T09:24:43Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-23T16:46:50Z — status-update [task-update-agent]
- **Change:** horizon: later → next

### 2026-04-24T09:24:43Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** Recommendation: DEFER — speculative pattern harvest, no current need.

Rationale: Captured from T-697 pattern harvest (KCP pattern #9) as a "potentially relevant for TermLink multi-agent" note. No concrete cross-machine knowledge graph problem exists today — TermLink handles its own cross-machine coordination via hub/secret and the framework uses per-project isolation. Re-evaluate when: (a) cross-machine knowledge sharing becomes a friction point, or (b) a concrete multi-agent federation use case emerges.

Evidence:
- Source: T-697 pattern harvest (captured, not applied)
- Horizon: later (correctly parked)
- No active federation scenario — framework uses pickup envelopes + TermLink remote for cross-machine today

### 2026-04-28T16:09:25Z — status-update [task-update-agent]
- **Change:** horizon: next → next

### 2026-04-28T20:02:47Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-05-15T19:54:39Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: started-work → captured (auto-sync)
- **Reason:** T-1865 sweep: DEFER limbo recovery
