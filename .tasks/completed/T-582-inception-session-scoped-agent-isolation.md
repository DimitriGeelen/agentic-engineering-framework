---
id: T-582
name: "Inception: Session-scoped agent isolation — session keys + crash recovery for
  concurrent agents"
description: >
  Two concurrent agents sharing a project corrupt each others focus, session state,
  and working memory. Already hit in practice: fw-agent + openclaw-eval + 150-skills-manager
  all active simultaneously. T-560 session-stamped focus is a crude single-writer
  lock, not true isolation. Investigate: (1) Session key pattern from OpenClaw (agent:<id>:<scope>)
  giving each agent its own namespace (.context/working/<session-key>/). Blast radius:
  touches every agent that reads .context/working/. (2) Crash recovery: detect stale
  sessions (no heartbeat >5min), archive orphaned state, reset focus. Add to fw context
  init. Already hit: eval agent compacted and sat idle with stale state, previous
  sessions left orphaned focus files. Research source: /opt/openclaw-evaluation/.context/working/round2-T-018.md
  (full isolation analysis). OpenClaw source: src/agents/session-manager.ts (session
  key derivation), src/gateway/runtime-state.ts (process registry + TTL), src/agents/agent-runtime.ts
  (crash recovery: kill children, flush queues, archive transcript). Related framework:
  agents/context/lib/focus.sh (current single-file focus), agents/context/lib/init.sh
  (context init — integration point for crash recovery), T-560 (session-stamped focus
  — predecessor).

status: work-completed
workflow_type: inception
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-23T21:18:38Z
last_update: '2026-08-16T22:25:34Z'
date_finished: 2026-03-28T09:31:59Z
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
  - ts: '2026-08-16T22:25:34Z'
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

# T-582: Inception: Session-scoped agent isolation — session keys + crash recovery for concurrent agents

## Problem Statement

Concurrent agents sharing a project corrupt each other's focus, session state, and working memory. T-560 session stamping is stale-detection, not isolation. See `docs/reports/T-582-session-scoped-agent-isolation.md`.

## Assumptions

1. Concurrent agents are a real use case (TermLink workers) — validated
2. T-560 session stamping is insufficient — validated (deadlock on concurrent sessions)
3. Hybrid namespace (focus + budget only) is practical first step — validated (Option D)

## Exploration Plan

1. Review shared state in `.context/working/` — DONE
2. Review T-560 mechanism — DONE
3. Review OpenClaw session key pattern — DONE
4. Evaluate 4 isolation options — DONE
5. Go/No-Go — DONE

## Technical Constraints

- ~15 files read `.context/working/`, full namespacing has high blast radius
- focus.yaml and budget-status are the two highest-conflict files

## Scope Fence

**IN:** Session isolation for focus/budget, crash recovery design
**OUT:** Full multi-agent coordination, lock-free writes

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Concurrent agents are a real use case (validated: TermLink workers)
- Bounded solution exists (validated: Option D, 2-3 files)

**NO-GO if:**
- Only one agent ever runs per project (false — TermLink workers exist)
- T-560 is sufficient (false — deadlocks on concurrent sessions)

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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-27T19:14:40Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-28T09:31:59Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ba356b3e
- **Timestamp:** 2026-06-02T15:03:42Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
