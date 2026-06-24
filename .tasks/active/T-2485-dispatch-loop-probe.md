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
last_update: 2026-06-24T15:20:00Z
date_finished: null
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
