---
id: T-1270
name: "Peer-learning cron: every 15 min, connect to all reachable TermLink agents, exchange reflections on what we can learn from each other"
description: >
  Inception: design a cron job that every 15 minutes enumerates reachable TermLink sessions/hubs and exchanges short prompts — what did you learn, what could we teach each other, what friction do you see — producing an inbox of cross-session learnings

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-15T21:36:12Z
last_update: 2026-04-23T14:57:49Z
date_finished: 2026-04-23T14:57:49Z
---

# T-1270: Peer-learning cron: every 15 min, connect to all reachable TermLink agents, exchange reflections on what we can learn from each other

**Research artifact:** [docs/reports/T-1270-peer-learning-cron.md](../../docs/reports/T-1270-peer-learning-cron.md) — full analysis, per-session token cost math, NO-GO rationale, and `fw ask peers` alternative (see Recommendation below).

## Problem Statement

Multiple TermLink-connected sessions run in parallel (different projects, different tasks, different agents). Each accumulates learnings in isolation — the only cross-session knowledge flow today is manual: pickup envelopes, handovers, or humans relaying summaries. There is no ambient "hallway conversation" between agents. A 15-minute reflection cron would enumerate reachable peers, ask each a short prompt ("what did you learn in the last ~15 min; what friction; anything we should know"), collect responses into a shared inbox, and let each agent opportunistically ingest the digest on its next session-init. Goal: transform isolated silos into a loosely-coupled learning mesh without heavy orchestration.

**Who:** any agent participating in this framework ecosystem.
**Why now:** today's cross-session summary (framework+termlink update from 003-NTB-ATC-Plugin, T-1258 RCA from t1258-rca, ring20 auth-rot repros) each surfaced learnings that stayed trapped. Automating the exchange is cheaper than relying on ad-hoc pickups.

## Assumptions

- A1: A 15-minute cadence is fast enough to surface cross-session patterns without flooding agents with noise (tune if wrong)
- A2: A bounded reflection prompt (<200 tokens response) is enough to be useful and not cost-prohibitive
- A3: TermLink `remote inject` (or local `pty inject`) is the right delivery primitive — it reaches the session's PTY, the receiving agent decides whether to respond
- A4: Responses land in a shared inbox (pickup / bus / dedicated) and are ingested opportunistically — not forced synchronous
- A5: Self-dampening: no response is a valid response; missed cycles are fine
- A6: This should PROPAGATE — any agent running this cron should ask peers to adopt it too, so the mesh grows organically

## Exploration Plan

- Spike A: Enumerate reachable peers (local + all configured hubs via `termlink fleet doctor`) and classify — which are agents (tag contains `agent` or `pickup`) vs. passive bash shells
- Spike B: Define the reflection prompt envelope — format, size cap, required response shape (yaml? jsonl?)
- Spike C: Design the ingestion path — where do responses go? pickup inbox? new `.context/mesh/` dir? framework bus?
- Spike D: Design the propagation mechanism — how does agent A ask agent B to adopt the cron? inline in reflection prompt? separate "adoption" message?
- Spike E: Failure modes — what if all peers ignore us? What if one peer floods us? What if a peer responds with noise? (rate limiting, dedup, ignore-list)
- Spike F: Security / blast radius — can a compromised peer poison the mesh via reflection responses? (response sanitization, signed envelopes?)

## Technical Constraints

- TermLink `pty inject` is fire-and-forget — agent must respond via a separate channel (pickup, send-file, or bus post remote)
- Each reflection must be bounded: ~15-min cadence × 5 peers × ~200 tokens response = ~6k tokens / 15min budget per agent
- Response ingestion MUST NOT trigger the Claude Code budget gate — responses go to file, not directly into agent context
- Mesh must degrade gracefully: hub down, peer offline, secret rotation — none should crash the cron
- Propagation must not become a spam vector: adoption request once per peer, persisted locally (don't re-ask)
- Must obey Instruction Precedence — agents receiving a reflection prompt MUST still check task gate before acting

## Scope Fence

**IN:**
- Design of the cron + reflection script (no build yet)
- Envelope format (reflection request, response)
- Ingestion path
- Propagation mechanism (inline adoption request)
- Security considerations
- Recommendation with bounded build decomposition if GO

**OUT:**
- Actual build (post-GO)
- Replacing pickup inbox (this is adjacent, not a rewrite)
- Forcing synchronous RPC between agents (too heavy — inbox-based is the A2 choice)
- Modifying the boundary gate (see T-1268)

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
- Cross-session learning signal cannot be achieved with existing primitives (pickup, handover, bus)
- Per-agent token cost (~168K/day on peer chatter) is justified by learning yield
- A5 (self-dampening) and A6 (propagation) can be reconciled on a single channel

**NO-GO if:**
- Existing primitives cover the concrete cases the cron would serve
- Polling introduces Goodhart feedback loop (agents manufacture learnings to satisfy the prompt)
- A caller-initiated alternative (`fw ask peers`) delivers the same benefit at fraction of the cost

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** NO-GO as scoped. GO-REDESIGN via `fw ask peers "question"` (caller-initiated alternative).

**Rationale:** The 15-minute reflection cron fails all three GO criteria. Existing primitives (pickup envelopes, handovers, bus) already cover intentional cross-session flows. The gap is *ad-hoc peer query*, not polling. Polling introduces a Goodhart loop — agents prompted every 15 minutes to "share a learning" will manufacture low-signal reflections to satisfy the cron, polluting the learning register. The caller-initiated alternative pays only when the caller judges the question worth asking, is caller-accountable, and propagates organically.

**Evidence:**
- **Cost:** 96 cycles/day × 5 peers × 350 tokens ≈ 168K tokens/day per agent on peer chatter alone — ~56% of a single 300K context window (docs/reports/T-1270-peer-learning-cron.md:38-46)
- **A5 contradicts A6:** Self-dampening ("no response is valid") dooms propagation via inline adoption — same channel, same ignore semantics (docs/reports/T-1270-peer-learning-cron.md:52)
- **Existing primitives cover the cases:** pickup envelopes handle intentional handoffs; handovers propagate narrative; bus handles sub-agent results (docs/reports/T-1270-peer-learning-cron.md:54-57)
- **Alternative costed:** `fw ask peers` — ~150-200 LoC shell + 2 bats tests, ~1 session, zero standing cost (docs/reports/T-1270-peer-learning-cron.md:69)
- **Full dialogue log + assumption testing** in research artifact (docs/reports/T-1270-peer-learning-cron.md)

**If human still wants the cron** (overriding NO-GO): decompose into T-1270a (reflection envelope + ingestion, manual only), T-1270b (cron scheduler, opt-in via `FW_PEER_LEARNING_CRON=1`), T-1270c (propagation). Build T-1270a first and measure signal-to-noise for 1 week before proceeding.

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

**Rationale**: Recommendation: NO-GO as scoped. GO-REDESIGN via `fw ask peers "question"` (caller-initiated alternative).

Rationale: The 15-minute reflection cron fails all three GO criteria. Existing primitives (pickup envelopes, handovers, bus) already cover intentional cross-session flows. The gap is ad-hoc peer query, not polling. Polling introduces a Goodhart loop — agents prompted every 15 minutes to "share a learning" will manufacture low-signal reflections to satisfy the cron, polluting the learning register. The caller-initiated alternative pays only when the caller judges the question worth asking, is caller-accountable, and propagates organically.

Evidence:
- Cost: 96 cycles/day × 5 peers × 350 tokens ≈ 168K tokens/day per agent on peer chatter alone — ~56% of a single 300K context window (docs/reports/T-1270-peer-learning-cron.md:38-46)
- A5 contradicts A6: Self-dampening ("no response is valid") dooms propagation via inline adoption — same channel, same ignore semantics (docs/reports/T-1270-peer-learning-cron.md:52)
- Existing primitives cover the cases: pickup envelopes handle intentional handoffs; handovers propagate narrative; bus handles sub-agent results (docs/reports/T-1270-peer-learning-cron.md:54-57)
- Alternative costed: `fw ask peers` — ~150-200 LoC shell + 2 bats tests, ~1 session, zero standing cost (docs/reports/T-1270-peer-learning-cron.md:69)
- Full dialogue log + assumption testing in research artifact (docs/reports/T-1270-peer-learning-cron.md)

If human still wants the cron (overriding NO-GO): decompose into T-1270a (reflection envelope + ingestion, manual only), T-1270b (cron scheduler, opt-in via `FW_PEER_LEARNING_CRON=1`), T-1270c (propagation). Build T-1270a first and measure signal-to-noise for 1 week before proceeding.

**Date**: 2026-04-23T12:10:38Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-22T11:36:44Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-23T12:10:38Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** NO-GO
- **Rationale:** Recommendation: NO-GO as scoped. GO-REDESIGN via `fw ask peers "question"` (caller-initiated alternative).

Rationale: The 15-minute reflection cron fails all three GO criteria. Existing primitives (pickup envelopes, handovers, bus) already cover intentional cross-session flows. The gap is ad-hoc peer query, not polling. Polling introduces a Goodhart loop — agents prompted every 15 minutes to "share a learning" will manufacture low-signal reflections to satisfy the cron, polluting the learning register. The caller-initiated alternative pays only when the caller judges the question worth asking, is caller-accountable, and propagates organically.

Evidence:
- Cost: 96 cycles/day × 5 peers × 350 tokens ≈ 168K tokens/day per agent on peer chatter alone — ~56% of a single 300K context window (docs/reports/T-1270-peer-learning-cron.md:38-46)
- A5 contradicts A6: Self-dampening ("no response is valid") dooms propagation via inline adoption — same channel, same ignore semantics (docs/reports/T-1270-peer-learning-cron.md:52)
- Existing primitives cover the cases: pickup envelopes handle intentional handoffs; handovers propagate narrative; bus handles sub-agent results (docs/reports/T-1270-peer-learning-cron.md:54-57)
- Alternative costed: `fw ask peers` — ~150-200 LoC shell + 2 bats tests, ~1 session, zero standing cost (docs/reports/T-1270-peer-learning-cron.md:69)
- Full dialogue log + assumption testing in research artifact (docs/reports/T-1270-peer-learning-cron.md)

If human still wants the cron (overriding NO-GO): decompose into T-1270a (reflection envelope + ingestion, manual only), T-1270b (cron scheduler, opt-in via `FW_PEER_LEARNING_CRON=1`), T-1270c (propagation). Build T-1270a first and measure signal-to-noise for 1 week before proceeding.

### 2026-04-23T14:57:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
