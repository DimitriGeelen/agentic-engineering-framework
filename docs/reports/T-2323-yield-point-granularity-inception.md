---
task: T-2323
title: "AEF-IC-1: Yield-point granularity — where in the agent's tool loop does the harness check the parallel-execution flag?"
arc: parallel-execution-aef
status: open
created: 2026-06-25
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

_Empty — ready for human dialogue sessions. Record questions, answers, course corrections, and the decision that results._

| # | Who | Exchange |
|---|-----|----------|
| — | — | _(no dialogue recorded yet)_ |

---

## Findings

_Populated as dialogue proceeds._

---

## Recommendation

_Not yet set — inception requires dialogue before a recommendation can be made._
