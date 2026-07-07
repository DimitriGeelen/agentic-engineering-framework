---
id: T-2485
name: "dispatch loop probe (T-2484 spike 2)"
description: >
  Throwaway probe to prove the orchestrator dispatch loop turns over end-to-end
  (T-2484 Spike 2). The dispatched worker must make NO file changes — just confirm
  it received the dispatch and stop. Zero blast radius by design.
status: started-work
workflow_type: build
owner: human
horizon: now
tags: [probe, throwaway, dispatch-test]
components: []
related_tasks: [T-2484]
created: 2026-06-24T15:20:00Z
last_update: '2026-07-07T08:00:09Z'
date_finished:
cost_estimate_proposed:
  - ts: '2026-07-07T08:00:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 1
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=1 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-07T08:00:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 3
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=2 (body:telemetry-or-audit-entry); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=3 
      (body:typed-io-or-gate); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2485: dispatch loop probe (T-2484 spike 2)

## Context

This task exists ONLY as a dispatch payload to prove the orchestrator chain
(triage → craft → route → spawn → capture-outcome) turns over with a real worker.
It is throwaway. Delete after Spike 2.

## Acceptance Criteria

### Agent
- [ ] Worker confirms it received and read this dispatch envelope, then stops.
      Make NO file changes — no Edit, no Bash that writes, no commits. The ONLY
      required action is to return a one-line confirmation that the dispatch was
      received. This task is a connectivity probe, not real work.

## Verification

# No verification — this is a no-op probe. The proof is a dispatches.jsonl row
# with a matched outcome, observed by the dispatching Agent (T-2484), not by the worker.
