---
id: T-2323
name: "AEF-IC-1: Yield-point granularity (substrate ADR §6.1) — where in the agent's
  tool loop does the harness check the parallel-execution flag and yield-point ear?"
description: >
  First downstream inception unblocked by T-2303 GO. Substrate ADR §6.1 open question:
  yield-point granularity decision. No substrate dependency (pure AEF-side harness
  decision). One question: where in the agent's tool loop does the harness check the
  parallel-execution flag and yield-point ear?

status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: [arc-parallel-execution-aef, downstream-of-T-2303, harness, yield-point]
components: []
related_tasks: [T-2303]
arc_id: parallel-execution-aef
created: 2026-06-10T20:07:03Z
last_update: 2026-06-25T14:03:36Z
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-06-10T20:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T20:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-10T20:15:03Z'
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
  - ts: '2026-06-11T20:15:03Z'
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
  - ts: '2026-06-13T18:00:05Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F-AUTONOMY=2 
      (no-signal); F3=2 (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2323: AEF-IC-1: Yield-point granularity (substrate ADR §6.1) — where in the agent's tool loop does the harness check the parallel-execution flag and yield-point ear?

## Problem Statement

T-2303 GO (recorded 2026-06-10 commit `989fc1e6e`) authorised the AEF-IC-1..IC-5 downstream-inception cluster. This is the first inception to file — AEF-IC-1 — and it carries the *substrate ADR §6.1 yield-point granularity* question. The substrate side has no opinion: this is an AEF-harness decision in full.

The question is concrete: **where in the agent's tool loop does the harness check the parallel-execution flag and yield-point ear?** Three candidate granularities surfaced during T-2303 prep (Spike 5 work log):

1. **Per-tool-call boundary** — the harness yields before *every* tool invocation, regardless of side effect. Pros: maximum responsiveness to flag flips; cons: high overhead on read-only tool sprawl.
2. **Per-file-write boundary** — the harness yields before any tool that *writes* (Edit, Write, Bash with redirect). Leading candidate per T-2303 prep work — matches the disjoint-write-set policy AEF-IC-2 will pin (the only collisions that matter are write collisions). Pros: aligns with what governance actually cares about; cons: requires per-tool classification of "is this a write?".
3. **Per-message boundary** — the harness yields once per assistant turn. Pros: cheapest; cons: a single turn can do dozens of writes before the next yield, defeating the purpose of disjoint-write-set proof in real time.

The decision binds: AEF-IC-4 (sidecar + cooperative-poll harness) consumes whichever granularity wins here as its ear-check semantics. Get this wrong → harness either thrashes (option 1 over-yields) or fails silently (option 3 misses a window).

**For whom:** AEF orchestrator + every worker agent running inside the parallel-execution arc. **Why now:** AEF-IC-2 + IC-3 + IC-4 cannot land coherent designs until the granularity choice is pinned. Bottleneck of the downstream DAG.

## Assumptions

- A1: The harness is implemented as a wrapper around `claude` (or equivalent agent process), not as a modification to Claude Code itself. Yield-point logic lives in AEF-controlled code.
- A2: The parallel-execution flag is observable from the harness's process space (env var read at startup AND/OR sidecar file polled at yield points AND/OR hub-state RPC). Spike work will pin which combination.
- A3: "Yield-point ear" semantics = the harness pauses, polls the flag's current value, and either continues or yields to a coordinator (per substrate §4 active-dispatcher design). The "ear" is the polling subroutine.
- A4: The decision is binary in granularity choice but composite in mechanism — i.e. the answer might be "Granularity (2) per-file-write + Mechanism (sidecar+poll)" or "Granularity (2) + Mechanism (env+hub-state)". This inception scopes the granularity AND the mechanism together because they bind each other.

## Open Questions

- **IW-1: Which yield-point granularity wins — per-tool-call, per-file-write, or per-message boundary?**
  confidence: 5
  disposition: answered
  answer: per-file-write
  rationale: Operator-confirmed (dialogue 2026-06-25/26). The yield-point that matters is "I'm about to write" — write collisions on disjoint write-sets are the only collisions the harness exists to prevent. Per-tool-call over-yields on read-only sprawl (grep/read/list); per-message is too coarse (warning lands after the conflicting write). Caveat: assumes a write-classifier (couples to AEF-IC-2 / T-2324).

- **IW-2: What is the flag's source-of-truth mechanism — env var, sidecar file, hub-state RPC, or composite?**
  confidence: 4
  disposition: answered-with-IC-4-handoff
  answer: local atomically-written per-agent file co-locating {dirty, priority, heartbeat_ts}
  rationale: Operator-confirmed (dialogue 2026-06-25/26). The AGENT reads a LOCAL, atomically-written (write-temp-rename), PER-AGENT file keyed by agent_id (e.g. ~/.termlink/harness/<agent_id>.flag) that co-locates flag + heartbeat (ADR §6.3). Co-location is the safety property — one staleness check covers both dead-sidecar and stuck-flag. Fail-closed (missing/stale/unreadable ⇒ deaf ⇒ STOP) + initial-heartbeat handshake. The "how the sidecar LEARNS of a flip" sub-choice (kv watch vs topic-tail) is sidecar-internal → deferred to AEF-IC-4. Rejected: env var (startup-only), hub-state RPC direct (network cost + hub load spike).

- **IW-3: What's the ear-check poll cadence + cost budget?**
  confidence: 5
  disposition: answered
  answer: local read (µs/check), trivially inside ≤5% harness-overhead budget
  rationale: Effectively decided by cost math once IW-1=per-file-write. Local read = one stat/read + timestamp subtraction ≈ µs; ~1000 checks/task ≈ a few ms total — non-issue against the ≤5% budget. Hub-KV-direct rejected: network RPC per check ≈ ms ×1000 = seconds/task + self-inflicted hub load spike (T-1991 traffic class, substrate ADR §10). "Local read, done" — not an open number.

## Exploration Plan

Three spikes (A: granularity dialogue / B: mechanism dialogue / C: cost model). All three are operator-dialogue spikes, not code spikes — the data needed is decision rationale, not implementation results. Time-box per CLAUDE.md inception conventions: 1 dialogue session per spike, ~30 min each.

## Technical Constraints

The harness runs as a wrapper around `claude` CLI. Constraints:
- **No Claude Code internals modification** — yield-point logic must live in AEF-side wrapper code (`bin/claude-fw` extension, or new `agents/harness/` subsystem).
- **Backward compatible with single-agent mode** — when parallel-execution flag is OFF, yield-point checks must be no-op (zero overhead, identical behavior to non-harness sessions).
- **No new daemon processes during transition** — yield-point check must be inline polling, not a sidecar daemon (the sidecar listener is AEF-IC-4's scope, not IC-1's).

## Scope Fence

**IN scope:**
- Yield-point granularity choice (per-tool-call / per-file-write / per-message)
- Flag source-of-truth mechanism choice (env / sidecar / hub / composite)
- Ear-check cost model + budget

**OUT of scope (deferred to other inceptions):**
- Sidecar daemon design — AEF-IC-4
- Active-dispatcher RPC shape — AEF-IC-3
- Disjoint-write-set algorithm — AEF-IC-2
- Substrate-side primitives — TermLink TL-IC-1
- Build implementation — separate build tasks post-AEF-IC-1 GO

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- IW-1 resolved: yield-point granularity pinned (one of per-tool-call / per-file-write / per-message), with operator-confirmed rationale
- IW-2 resolved: flag source-of-truth mechanism pinned (env / sidecar / hub / composite), with rationale citing staleness + race characteristics
- IW-3 resolved: ear-check cost budget defined (e.g. "≤ 5% harness overhead at p99") + measurement protocol
- Decision rationale captured in `## Decisions` + Dialogue Log (when present)
- AEF-IC-4 (sidecar+harness) can consume the granularity decision as ear-check semantics input

**NO-GO if:**
- Spike dialogue surfaces that the granularity question is malformed (e.g. yield-points need to be event-driven not poll-based — kicks back to a substrate-side IC or a new AEF-IC-N)
- Cost model shows ear-check overhead is unbounded at any practical granularity (kicks parallel-execution arc to a fundamentally different mechanism — likely AEF-IC-5 absorption)

**DEFER if:**
- Operator wants AEF-IC-2 (disjoint-write-set policy) to resolve first since per-file-write granularity assumes a write classifier exists; concrete revisit trigger logged

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO

**Rationale:** The scoping-phase evidence gap is now filled — operator dialogue (2026-06-25/26, logged in `docs/reports/T-2323-yield-point-granularity-inception.md`) converged all three open questions: IW-1 = per-file-write; IW-2 = local atomically-written per-agent file co-locating `{dirty, priority, heartbeat_ts}` (sidecar-fill mechanism deferred to AEF-IC-4), fail-closed + initial-heartbeat handshake; IW-3 = local read (µs/check, ≤5% budget non-issue). The decision is coherent, fail-closed, and consumable by AEF-IC-4 as ear-check semantics. The prior DEFER was the legitimate scoping-phase recommendation (the evidence gap WAS the dialogue); per T-2144, holding DEFER now that the artifact is complete would be a confidence-calibration hedge, not a knowledge gap.

**Coupling:** GO depends on the AEF-IC-2 (T-2324) write-classifier landing (per-file-write assumes a write classifier). The outbound ack-with-retry leg ties to TermLink T-2285 (same build territory — the bidirectional sidecar is that retry helper's home).

**Decision ownership:** Agent advisory. The human owns the GO/NO-GO via `fw inception decide T-2323 go`. No decision recorded by this recording session.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

### 2026-06-26 — Yield-point granularity + flag mechanism (dialogue convergence)
- **Chose:** **Per-file-write** yield-point granularity (IW-1). Flag mechanism (IW-2) = a **local, atomically-written (write-temp-rename), per-agent file** keyed by `agent_id` that **co-locates** the flag and heartbeat: schema `{dirty: bool, priority: u8, heartbeat_ts}` (ADR §6.3). Cost budget (IW-3) = **local read** (µs/check) — trivially inside the ≤5% harness-overhead budget. Fail-closed lifecycle (missing/stale/unreadable ⇒ deaf ⇒ STOP) + initial-heartbeat handshake.
- **Why:** Write collisions on disjoint write-sets are the only collisions the harness exists to prevent, so the yield-point that matters is "I'm about to write". Co-locating flag + heartbeat means a single staleness check covers both dead-sidecar and stuck-flag failure modes — this is the safety property that makes the local file safe rather than racy. The governing asymmetry (a false "deaf" only pauses; a false "all clear" lets a collision through) forces every ambiguous state to resolve to deaf ⇒ stop.
- **Rejected:** Per-tool-call (over-yields on read-only sprawl — grep/read/list — where no collision can occur); per-message (too coarse — a turn can do many writes before yielding, so the warning lands AFTER the conflicting write); env-var flag (startup-only, no mid-session updates); hub-state RPC direct per check (network cost ms ×1000 = seconds/task PLUS a self-inflicted hub load spike, T-1991 traffic class / substrate ADR §10).
- **Deferred:** The "how does the sidecar LEARN of a flip" sub-choice (`termlink kv watch` vs topic-tail) is sidecar-internal → **AEF-IC-4** (sidecar design). T-2323 only fixes that the AGENT reads a local co-located file.
- **Coupling:** per-file-write assumes a write-classifier → **AEF-IC-2 (T-2324)**. Outbound sender-side ack-with-retry → **TermLink T-2285** (the bidirectional sidecar is that client-side retry helper's home).
- **Decision ownership:** Agent advisory only. Overall inception GO/NO-GO stays with the human via `fw inception decide T-2323 go`. No decision recorded by this recording session.

## Decision

**Decision**: DEFER

**Rationale**: Scoping inception — the question itself (where does the harness check?) is the evidence gap. Spike dialogue resolves: (a) yield-point granularity (file-write boundary vs tool-call boundary vs message boundary); (b) flag shape (env var vs sidecar file vs hub-state poll); (c) ear-check semantics (poll cadence + busy/idle response shape). Leading candidate per T-2303 Spike 5 prep work: 'before every file-write tool call' — but this needs operator dialogue to pin. Legitimate evidence-gap DEFER per T-2144 — this inception's job is to gather the evidence via spike dialogue. Concrete revisit trigger: operator-led spike dialogue session OR first downstream build pressure on harness design (whichever lands first).

**Date**: 2026-06-10T21:55:57Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6d8d62da
- **Timestamp:** 2026-06-10T20:09:17Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-10T21:55:57Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** Scoping inception — the question itself (where does the harness check?) is the evidence gap. Spike dialogue resolves: (a) yield-point granularity (file-write boundary vs tool-call boundary vs message boundary); (b) flag shape (env var vs sidecar file vs hub-state poll); (c) ear-check semantics (poll cadence + busy/idle response shape). Leading candidate per T-2303 Spike 5 prep work: 'before every file-write tool call' — but this needs operator dialogue to pin. Legitimate evidence-gap DEFER per T-2144 — this inception's job is to gather the evidence via spike dialogue. Concrete revisit trigger: operator-led spike dialogue session OR first downstream build pressure on harness design (whichever lands first).

### 2026-06-10T21:55:57Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: started-work → captured (auto-sync)
- **Reason:** Inception decision: DEFER — parking task

### 2026-06-25T14:03:31Z — status-update [task-update-agent]
- **Change:** horizon: later → now

### 2026-06-25T14:03:36Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
