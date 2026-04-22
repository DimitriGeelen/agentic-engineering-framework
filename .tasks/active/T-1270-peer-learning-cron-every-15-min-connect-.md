---
id: T-1270
name: "Peer-learning cron: every 15 min, connect to all reachable TermLink agents, exchange reflections on what we can learn from each other"
description: >
  Inception: design a cron job that every 15 minutes enumerates reachable TermLink sessions/hubs and exchanges short prompts — what did you learn, what could we teach each other, what friction do you see — producing an inbox of cross-session learnings

status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-15T21:36:12Z
last_update: 2026-04-22T11:36:44Z
date_finished: null
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
- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Recommendation written with rationale

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

<!-- REQUIRED before fw inception decide. Write your recommendation here (T-974).
     Watchtower reads this section — if it's empty, the human sees nothing.
     Format:
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence from exploration)
     **Evidence:**
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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-22T11:36:44Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
