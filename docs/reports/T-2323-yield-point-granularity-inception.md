---
task: T-2323
title: "AEF-IC-1: Yield-point granularity — where in the agent's tool loop does the harness check the parallel-execution flag?"
arc: parallel-execution-aef
status: converged
created: 2026-06-25
dialogue_converged: 2026-06-26
companion_adr: docs/architecture/parallel-execution-aef.md
substrate_adr: docs/architecture/parallel-execution-substrate.md
seeded_by: termlink-substrate-agent cross-layer coordination (2026-06-25)
---

# T-2323: Yield-point Granularity (AEF-IC-1)

## Inception Question

**Where in the agent's tool loop does the harness check the parallel-execution flag and yield-point ear?**

Three candidate granularities exist. This inception pins one and documents the forcing reasoning.

---

## Context: Substrate Coordination State (as of 2026-06-25)

Verified by termlink-substrate-agent this session. **Do not re-derive** — treat as pass-through.

### What has shipped on the substrate side

The T-1800 "doorbell+mail" wake-up mechanism is **LIVE**:

- `termlink inject` = raw PTY-master write (`crates/termlink-session/src/pty.rs:249`)
- `scripts/agent-send.sh` — mail (channel post into a turn) + doorbell (inject `/check-arc`)
- `scripts/agent-respond.sh` — receipt + reply
- `listener-heartbeat.sh` — posts presence to agent-presence hub topic
- `agent-listeners.sh` — reads presence and classifies LIVE/STALE/OFFLINE by `now - last_seen`
- Skills: `/be-reachable`, `/peers`, `/check-arc`
- Fleet-doorbell-mail health canary + full operator runbooks

### Why the shipped PTY doorbell is NOT the answer for the parallel-BUILD harness

AEF ADR §5 **explicitly rejects** PTY injection for the parallel-execution harness:

> "it delivers into the input stream the agent is currently consuming… preemption is the wrong model"
> "the doorbell survives as intent, dies as implementation… the flag is a file / KV entry, not a keystroke"

The shipped PTY doorbell correctly serves **human-paced agent-to-agent handoff** (one agent handing off to another between turns). It is the **wrong primitive** for the parallel-build harness, where an agent may be mid-turn writing files and cannot safely be interrupted.

### The §5 chosen design (pre-build on both layers)

A **deterministic sidecar** (no LLM, not `claude -p`) holds the TermLink connection and:

1. Writes an **out-of-band flag** (file or KV entry) — NOT a PTY keystroke
2. Writes a **heartbeat timestamp** on a regular tick
3. The **agent** cooperatively polls: flag value + `now - last_heartbeat` at its own yield points
4. Stale heartbeat ⇒ listener dead ⇒ agent is deaf ⇒ **STOP BEFORE ACTING** (self-check-ears)
5. Sender-side missing-ack ⇒ retry (symmetric backstop)

### Substrate readiness for the §5 design

- **KV store EXISTS**: `termlink kv set/get/watch` — natural home for out-of-band flag + heartbeat timestamp
- **Offline-queue/reconnect**: partially shipped (substrate T-2051)
- **OPEN substrate gap named in §5**: ack-with-retry ("TermLink receipts are advisory today")

---

## Candidates

All three candidates come from T-2303 Spike 5 prep work. The leading candidate per the ADR prep is **Candidate 2** (per-file-write).

### Candidate 1: Per-tool-call boundary
Harness yields before **every** tool invocation regardless of side effect.

- Pros: maximum responsiveness to flag flips
- Cons: high overhead on read-only tool sprawl (grep, read, list); yield-check cost amortised poorly

### Candidate 2: Per-file-write boundary ← leading candidate
Harness yields before any tool that **writes** (Edit, Write, Bash with redirect/write).

- Pros: aligns with what governance actually cares about (only write collisions matter for disjoint-write-set policy); matches AEF-IC-2 scope boundary
- Cons: requires per-tool classification of "is this a write?"; must not miss Bash side effects
- ADR §6.1 note: "heartbeat lean 5s tick / 30s staleness threshold (a 6-beat window during which an agent may act while deaf)"

### Candidate 3: Per-message boundary
Harness yields once per assistant turn (after all tools in a turn complete).

- Pros: cheapest; trivial to implement
- Cons: a single turn can do dozens of writes before the next yield, defeating disjoint-write-set proof in real time; miss-window risk is high

---

## What would resolve this

This inception resolves through **operator dialogue** (not code spikes). Three questions need answers:

**IW-1 (granularity):** Which boundary wins — per-tool-call, per-file-write, or per-message? Leading candidate: per-file-write. Needs operator confirm of the cost/responsiveness tradeoff.

**IW-2 (flag mechanism):** What is the flag's source-of-truth — env var, sidecar file, hub KV (`termlink kv`), or composite? Each has different staleness/race characteristics:
  - env var = startup-only, no mid-session updates
  - sidecar file = stale-read race (parallel of L-477 + T-2322 sidecar-degradation class)
  - hub KV = network cost per yield
  - composite (env at start + hub KV on demand) = likely answer, needs operator confirm

**IW-3 (cost budget):** At per-file-write granularity, ear-check fires hundreds of times per task. Need explicit budget before AEF-IC-4 designs the polling loop (e.g. "ear-check cost ≤ 5% of total harness overhead at p99").

**Downstream dependency:** AEF-IC-4 (sidecar + cooperative-poll harness) consumes whichever granularity wins here as its ear-check semantics. T-2323 is the bottleneck of the downstream DAG (AEF-IC-2, IC-3, IC-4 cannot land coherent designs until this is pinned).

---

## Go/No-Go Criteria

**GO if:**
- IW-1 pinned (one granularity chosen with operator-confirmed rationale)
- IW-2 pinned (flag mechanism chosen, citing staleness + race characteristics)
- IW-3 defined (ear-check cost budget + measurement protocol)
- Decision captured in `## Decisions` on the task + Dialogue Log below

**NO-GO if:**
- Spike dialogue surfaces the granularity question is malformed (e.g. yield-points should be event-driven not poll-based — kicks back to a new IC or substrate-side IC)
- Cost model shows ear-check overhead unbounded at any practical granularity

**DEFER if:**
- Operator wants AEF-IC-2 (disjoint-write-set policy) to resolve first because per-file-write granularity assumes a write-classifier exists. Concrete revisit trigger: AEF-IC-2 GO or first downstream build pressure.

---

## Scope Fence

**IN scope:** granularity choice, flag mechanism choice, ear-check cost model

**OUT of scope:**
- Sidecar daemon design → AEF-IC-4
- Active-dispatcher RPC shape → AEF-IC-3
- Disjoint-write-set algorithm → AEF-IC-2
- Substrate-side primitives → TermLink TL-IC-1
- Build implementation → separate build tasks post-GO

---

## Dialogue Log

Session 2026-06-25/26, operator + termlink-substrate-agent (cross-layer facilitation). The three open questions (IW-1 granularity, IW-2 flag mechanism, IW-3 cost budget) were worked through to convergence.

| # | Who | Exchange |
|---|-----|----------|
| 1 | Agent | Posed IW-1: which yield-point granularity wins — per-tool-call, per-file-write, or per-message? Leading candidate from T-2303 prep is per-file-write. |
| 2 | Operator | **Chose per-file-write.** Reasoning: the whole point of the harness is preventing write collisions on disjoint write-sets, so the yield-point that matters is "I'm about to write". Per-tool-call burns overhead checking before read-only sprawl (grep/read/list) where no collision can occur. Per-message is too coarse — a turn can do many writes before yielding, so a warning lands AFTER the conflicting write. |
| 3 | Agent | Surfaced the caveat: per-file-write assumes a write-classifier, which couples to AEF-IC-2 (T-2324). |
| 4 | Operator | Asked: "what is the sidecar?" — wanted the mechanism explained before pinning IW-2. |
| 5 | Agent | Explained the sidecar: a separate OS process, 1:1 per agent, same host, deterministic (no LLM, not `claude -p`). Holds the persistent TermLink connection; writes a local flag+heartbeat file the agent reads at safe points. It is the INVERSION of the rejected PTY doorbell — cooperative (agent reads at a safe point) vs preemptive (inject a keystroke into the consumed input stream). |
| 6 | Operator | Asked the agent to explore other angles before converging. |
| 7 | Agent | Explored findings A–F (co-located heartbeat = safety; what the sidecar is + why deterministic; fail-closed lifecycle; the governing asymmetry; bidirectional sidecar tie to T-2285; ring20 per-agent reality). |
| 8 | Both | **Converged.** IW-1 = per-file-write. IW-2 = local atomically-written per-agent file co-locating {dirty, priority, heartbeat_ts}; the "how does the sidecar learn of a flip" sub-choice (kv watch vs topic-tail) is sidecar-internal and belongs to AEF-IC-4, not here. IW-3 = local read, decided by cost math (µs/check ≈ trivially inside the ≤5% budget; hub-KV-direct rejected — network RPC ×1000 + self-inflicted hub load spike per substrate ADR §10). |

---

## Findings

**A. Co-located heartbeat = safety, not convenience.** Flag + heartbeat in ONE atomically-written file (write-temp-rename) means you can never have a fresh flag with a stale heartbeat. "Sidecar stopped updating the flag" is indistinguishable from "sidecar stopped updating the heartbeat" — so the single heartbeat-staleness check covers BOTH failure modes (dead sidecar AND stuck flag). This is what makes the local-file option safe rather than racy — it resolves the artifact's earlier "sidecar file = stale-read race" concern (IW-2 above), which only held when flag and heartbeat were separable.

**B. What the sidecar IS.** A separate OS process, 1:1 per agent, same host, deterministic (no LLM, not `claude -p`). Holds the persistent TermLink connection; writes the local flag+heartbeat file. Deterministic is correct on three axes (ADR §5):
- **Logic** — flipping a bit needs no reasoning.
- **Cost** — no per-message $ for a process that just polls and writes a file.
- **Responsiveness** — a free process can poll the hub aggressively and react in ms; an expensive `claude -p` would be woken infrequently to save money, reintroducing exactly the latency this design kills.

It is the INVERSION of the rejected PTY doorbell: it writes a file the agent reads at a safe point (cooperative) vs injecting a keystroke into the consumed input stream (preemptive).

**C. Lifecycle — fail-closed.** Self-check-ears (stale heartbeat) catches a sidecar that DIED. A sidecar that NEVER STARTED leaves no file → handle as: missing file = deaf = STOP (fail-closed), plus an initial-heartbeat handshake (the agent refuses its first write until it has seen one fresh heartbeat). This resolves ADR §5's spawner-supervision-vs-self-check fork toward self-check: safety depends only on the agent, the one thing certainly running when it is about to act.

**D. The governing asymmetry.** A false "deaf" only PAUSES an agent (cheap); a false "all clear" lets a COLLISION through (expensive). Every ambiguous state (missing file / stale heartbeat / unreadable) resolves to deaf ⇒ stop. This is the same CSMA/CD asymmetry that forced conservative-launch (ADR §3).

**E. The sidecar is BIDIRECTIONAL — ties to T-2285.** Inbound: hub → local flag file. Outbound: this agent's sends → ADR §5 "sender-side missing-ack ⇒ retry" = ack-with-retry = TermLink T-2285 (just made decision-ready: the recommendation is a CLIENT-side retry helper, no hub state). The sidecar IS that client-side helper's home. So T-2323's harness and T-2285's retry are the same build territory.

**F. Ring20 reality.** One-or-more agents per host ⇒ each agent gets its OWN sidecar + OWN flag file keyed by `agent_id` (no shared flag file — that would couple two agents' yield decisions). This matches the per-agent presence model already in `listener-heartbeat.sh`.

---

## Recommendation

**Recommendation:** GO

**Rationale:** All three open questions converged through operator dialogue (logged above). The decision is coherent, fail-closed, and consumable by AEF-IC-4 as ear-check semantics.

- **IW-1 (granularity) = per-file-write.** The yield-point that matters is "I'm about to write" — write collisions on disjoint write-sets are the only collisions the harness exists to prevent. Per-tool-call over-yields on read-only sprawl; per-message is too coarse (warning lands after the conflicting write).
- **IW-2 (flag mechanism) = local, atomically-written (write-temp-rename), per-agent file** keyed by `agent_id` (e.g. `~/.termlink/harness/<agent_id>.flag`) that CO-LOCATES the flag and the heartbeat: schema `{dirty: bool, priority: u8, heartbeat_ts}` (ADR §6.3). Co-location is the safety property (Finding A): one staleness check covers both dead-sidecar and stuck-flag. Fail-closed lifecycle — missing file / stale heartbeat / unreadable ⇒ deaf ⇒ STOP — plus an initial-heartbeat handshake before the first write (Findings C, D). The "how does the sidecar LEARN of a flip" sub-choice (`termlink kv watch` vs topic-tail) is sidecar-internal and **deferred to AEF-IC-4**; T-2323 only fixes that the AGENT reads a local co-located file.
- **IW-3 (cost budget) = local read.** At per-file-write granularity the ear-check fires hundreds of times/task. Local read = one stat/read + timestamp subtraction ≈ µs; ~1000 checks ≈ a few ms total — trivially inside the "≤5% harness overhead" budget. Hub-KV-direct rejected: a network RPC per check ≈ ms ×1000 = seconds/task PLUS a self-inflicted hub load spike (the T-1991 traffic class substrate ADR §10 warns about). IW-3 is "local read, done" — not an open number once IW-1 = per-file-write.

**Coupling notes:**
- **AEF-IC-2 (T-2324) write-classifier coupling** — per-file-write assumes a classifier answering "is this tool call a write?". That classifier is AEF-IC-2's scope; this GO depends on it landing.
- **T-2285 bidirectional-sidecar tie** — the outbound leg (sender-side missing-ack ⇒ retry) is TermLink T-2285's client-side retry helper. The sidecar is that helper's home; T-2323's harness and T-2285's retry are the same build territory (Finding E).

**Decision ownership:** This is the agent's advisory recommendation. The human owns the GO/NO-GO via `fw inception decide T-2323 go`. No decision has been recorded by this recording session.
