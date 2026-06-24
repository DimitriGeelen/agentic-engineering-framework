---
id: T-2484
name: "orchestrator dispatch spine: one real end-to-end dispatch then iterate"
description: >
  Inception: the orchestrator has never made a single real dispatch. Define the
  minimal vertical slice that gets ONE real triage->craft->route->spawn->outcome
  dispatch to land, and triage the ~30 existing orchestrator tasks into
  critical-path / defer / kill.

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: [orchestrator, dispatch, triage, spine]
components: []
related_tasks: [T-1773, T-1774, T-1775, T-1797, T-1636, T-1685, T-1687, T-1792]
created: 2026-06-24T15:07:23Z
last_update: 2026-06-24T15:10:13Z
date_finished: null
target_blast_radius: 5            # cross-subsystem (orchestrator/resolver/dispatch + worker primitives)
voi_score: 0.9                    # unblocks the operator's stated top priority + gates all parallel-execution work
---

# T-2484: orchestrator dispatch spine: one real end-to-end dispatch then iterate

## Problem Statement

**The orchestrator has never made a single real dispatch.** `fw orchestrator status`
returns *"no dispatches captured yet"* — `.context/dispatches.jsonl` is empty. Zero,
not few.

Meanwhile ~30+ active tasks have built orchestrator *substrate*: the resolver, dispatch
envelopes, outcome backprop, worker primitives (T-1773/74/75 spawn driver + `fw resolver
run`; T-1797 TermLink worker), peer-consult (T-1818-21), and a shelf of Watchtower panels
(T-1792-1807: by_model / by_task_type / by_worker_kind / outcome-quality / workflow-coverage).

This is the scope-creep pattern at its largest scale: **we built dashboards, breakdowns,
and observability for a dispatch loop that has never run once.** The spine —
triage -> craft -> route -> spawn worker -> capture outcome — was never wired into a working
loop, so (as the operator put it) "it all falls apart, collapses and stays single-agent
execution."

**For whom:** the operator (Dimitri), who intends to scale to many parallel agents soon.
**Why now:** this week's worktree/merge-back work surfaced that the keystone the whole
parallel-execution model depends on — the orchestrator — was never wired. Every downstream
capability (including the per-task light/heavy worktree routing decision designed in the
2026-06-24 dialogue) is an *orchestrator function* and cannot exist until the spine turns
over once.

## Assumptions

<!-- Register with: fw assumption add "Statement" --task T-2484 -->
- **A1** — A minimal vertical slice (one real end-to-end dispatch) is achievable by
  *composing existing* primitives/tasks, not by new construction.
- **A2** — Most of the ~30 orchestrator tasks are premature decoration (panels/breakdowns)
  safely deferrable until the spine runs once.
- **A3** — The spawn driver (T-1773/74) + worker primitive (T-1775/T-1797) + resolver
  (`fw resolver dispatch`) are the critical path; the panels are not.

## Open Questions

- **IW-1: What is the minimal definition of "one real end-to-end dispatch"?**
  confidence: 2
  disposition: answered
  rationale: Operator dialogue 2026-06-24 — bar is one real triage->craft->route->spawn
  worker->capture-outcome-row-in-dispatches.jsonl, handed-in (not autonomously picked),
  then iterate to many quickly. Autonomous queue-picking is explicitly slice 2+.

- **IW-2: Which of the ~30 existing orchestrator tasks are critical-path vs defer vs kill?**
  confidence: 0
  disposition: deferred
  rationale: Requires Spike 1 (substrate map) + Spike 2 (manual one-dispatch attempt) before
  a defensible triage. This is the inception's core deliverable.

- **IW-3: What is the smallest real task to use as the first dispatch payload?**
  confidence: 1
  disposition: deferred
  rationale: Needs a safe, bounded, idempotent task (candidate: a read-only analytical job
  like `fw audit` routing per T-1685, or a trivial scoped build). Decide during Spike 2.

- **IW-4: Does slice 1 need autonomous queue-picking?**
  confidence: 3
  disposition: dissolved
  rationale: Operator answered NO — "start with one and then have more quickly." Picking is
  out of scope for slice 1; the orchestrator executes one dispatch we hand it, then iterate.

## Exploration Plan

- **Spike 1 — substrate map (time-box: 1 session).** Read T-1773/74/75/1797/1636 + the live
  `fw resolver`, `fw orchestrator`, `fw outcome` CLI surfaces. Map what is actually
  implemented vs stubbed vs missing along the triage->craft->route->spawn->outcome chain.
- **Spike 2 — manual one-dispatch attempt (time-box: 1 session).** Try to drive ONE real
  dispatch end-to-end using only existing verbs (`fw resolver dispatch` -> spawn worker ->
  `fw outcome backprop`). Find the first place the chain breaks. The break point *is* the
  first build slice.
- **Triage.** Classify the ~30 orchestrator tasks into critical-path / defer / kill against
  the spine the spikes reveal.

## Technical Constraints

- Worker execution substrate is TermLink (`fw termlink dispatch`) and/or `claude -p`
  (L-346: `claude -p` exit=0 is NOT a tool-use signal). Spine must capture a real outcome
  row, not just a spawn.
- Dispatch write path is `.context/dispatches.jsonl`; outcomes are `dispatch-outcomes.jsonl`.
  The spine is "real" only when a matched dispatch+outcome pair exists.
- Single-host first; cross-machine dispatch is out of scope for the spine.

## Scope Fence

**IN:** defining the spine; one real dispatch landing a row in `dispatches.jsonl` with a
matched outcome; triaging the existing orchestrator backlog.

**OUT (explicitly deferred):** autonomous queue-picking; multi-worker parallelism; the
light/heavy worktree routing decision; any Watchtower orchestrator panel work
(T-1792-1807); multi-LLM cost-aware routing (T-1637); peer-consult (T-1818-21).

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated (orchestrator-never-dispatched confirmed live)
<!-- @auto-tick-on-decide -->
- [ ] Assumptions A1-A3 tested via Spike 1 + Spike 2
<!-- @auto-tick-on-decide -->
- [ ] Backlog triaged: ~30 orchestrator tasks classified critical-path / defer / kill
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale + named first build slice

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go on the first build slice
  **Steps:**
  1. Run: `cd /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation && bin/fw task review T-2484`
  2. Review the Recommendation + the backlog triage table
  3. Record decision via the Watchtower form
  **Expected:** Decision recorded, first build slice authorised
  **If not:** Ask agent for clarification on the spine definition or triage

## Go/No-Go Criteria

**GO if:**
- A minimal spine is composable from existing primitives with a bounded, testable first
  build slice
- One real dispatch is demonstrably reachable (Spike 2 reaches outcome capture or names the
  single missing piece)

**NO-GO if:**
- The substrate is too fragmented to compose without a rewrite (then the real question is a
  redesign — a separate inception, not this one)

## Verification

# Inception — decision artifact, no build verification. Spike findings live in the
# research artifact docs/reports/T-2484-orchestrator-spine.md.

## Recommendation

<!-- Provisional framing; finalised after Spike 1 + Spike 2. -->
**Recommendation:** GO (provisional — confirm first build slice after spikes)
**Rationale:** "Orchestrator above all" is the operator's stated top priority (2026-06-24
dialogue). The substrate exists but has never turned over; the highest-leverage move is one
real dispatch, then iterate — not more substrate. The inception itself is self-limiting
(triage, not construction).
**Evidence:**
- `fw orchestrator status` -> "no dispatches captured yet" (`.context/dispatches.jsonl` empty)
- ~30 active orchestrator tasks built ahead of any working dispatch loop
- Operator directive: wire the orchestrator above all else; start with one dispatch then scale

## Decisions

### 2026-06-24 — isolation granularity is per-task, never per-arc
- **Chose:** worktree isolation (when used at all) is decided per-*task*, not per-*arc*.
- **Why:** arc-level worktrees batch a whole arc behind one merge — tasks pile up, closure
  becomes a hog, valuable improvements sit unlanded. Per-task landing keeps a continuous
  flow to master (continuous-integration argument).
- **Rejected:** "arc_id -> heavy lane" auto-isolation (the agent's initial heuristic) — it
  inverts the CI principle and was corrected by the operator.

### 2026-06-24 — orchestrator before worktree routing
- **Chose:** prioritise wiring the orchestrator spine above finishing worktree/merge-back tooling.
- **Why:** the light/heavy worktree routing decision is itself an orchestrator function; it
  cannot exist until the orchestrator dispatches at all. The merge-back work is parked (not
  wasted) as the eventual heavy-lane backend.
- **Rejected:** promoting `fw integrate go-live` / adding `fw worktree start` now (OBS-086
  follow-ups) — deferred until the spine exists and actually needs to route.

## Decision

<!-- Filled at completion via Watchtower / fw inception decide -->

## Updates

### 2026-06-24T15:10:13Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
