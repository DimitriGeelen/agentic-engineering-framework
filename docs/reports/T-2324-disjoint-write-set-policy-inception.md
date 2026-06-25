---
task: T-2324
title: "AEF-IC-2: Disjoint write-set policy — how does the orchestrator prove disjoint write-sets before parallel dispatch?"
arc: parallel-execution-aef
status: open
created: 2026-06-25
companion_adr: docs/architecture/parallel-execution-aef.md
substrate_adr: docs/architecture/parallel-execution-substrate.md
seeded_by: termlink-substrate-agent cross-layer coordination (2026-06-25)
---

# T-2324: Disjoint Write-Set Policy (AEF-IC-2)

## Inception Question

**How does the AEF orchestrator prove two tasks have disjoint write-sets before dispatching them in parallel?**

This inception pins the proof shape (static / dynamic / hybrid) and its failure mode: what happens when disjointness cannot be proven.

---

## Context: Substrate Coordination State (as of 2026-06-25)

Verified by termlink-substrate-agent this session. **Do not re-derive** — treat as pass-through.

### The forcing constraint (CSMA/CD reasoning)

From AEF ADR §6.2 + §3:

> Conservative-at-launch is **FORCED**. No filesystem-write observation exists. Optimistic-on-honour-system is unsafe. Bias to the cheap error.

This rules out any proof shape that relies on observing actual file writes at runtime (no FUSE layer, no inotify-based write intercept in scope). The proof must be **pre-dispatch** — declared or derived before the workers start.

The CSMA/CD analogy: agents cannot "sense" a collision before it happens, so the protocol must prevent collisions before they start (collision avoidance, not collision detection).

### Substrate readiness

The substrate side contributes **no blocking gaps** to this inception. KV, heartbeat, and flag primitives (T-2323's domain) are substrate concerns. The disjoint-write-set proof is entirely AEF-side orchestrator logic.

### Relationship to T-2323 (AEF-IC-1)

T-2323 asks *when* the agent checks (yield-point granularity). T-2324 asks *what* the orchestrator checks before dispatch. They are independent inception questions, but:

- Per-file-write granularity (T-2323 leading candidate) assumes a write-classifier exists
- That classifier's definition overlaps with this inception's "declared artifactWrites globs" concept
- If T-2323 resolves to per-file-write, T-2324's write-set model must be compatible

The two inceptions can resolve concurrently. If T-2323 picks per-message boundary (Candidate 3), the dependency dissolves.

---

## Candidates

From AEF ADR §6.2 prep work. The leading candidate per the ADR is **Candidate 3 (hybrid)**, forced by the conservative-at-launch constraint.

### Candidate 1: Static proof (frontmatter-declared)
Tasks declare `artifactWrites: [glob, ...]` in frontmatter. Orchestrator checks declared sets for overlap before dispatch.

- Pros: zero runtime cost; auditable before dispatch; compatible with T-2323 per-file-write classifier
- Cons: agents can write outside declared globs (declared ≠ actual); requires discipline to keep declarations accurate; false-disjoint risk if declarations drift

### Candidate 2: Dynamic proof (blast-radius predicted)
Orchestrator runs `fw fabric blast-radius` for each candidate task; predicts write-set from component dependency graph.

- Pros: no manual declaration required; leverages existing fabric tooling
- Cons: blast-radius predicts *read* impact (downstream consumers), not necessarily *write* locations; fabric cards may be stale (`fw fabric drift`); slow pre-dispatch (fabric blast-radius is not instant)

### Candidate 3: Hybrid ← leading candidate
Combine static declaration + dynamic prediction as a two-layer gate:
1. Static: tasks must declare `artifactWrites` globs (gate enforced at dispatch time, not lint time)
2. Dynamic: orchestrator runs glob intersection check on declared sets (no fabric involved at dispatch time)
3. If intersection non-empty OR either task has no declaration: **serialize** (do not dispatch in parallel)
4. Fabric blast-radius runs post-dispatch for audit/learning, not as a blocking gate

- Pros: cheap O(1) intersection check at dispatch; serialization is the safe fallback; declaration errors result in serialization not corruption; compatible with T-2323 write classifier
- Cons: requires authors to declare `artifactWrites`; incorrect declarations serialize unnecessarily (false-overlap) or skip serialization (false-disjoint); latter is the dangerous case

### Candidate 4: Serialize always (no proof)
Parallel dispatch never happens; tasks always serialize.

- Pros: trivially safe; no infrastructure needed
- Cons: defeats the entire purpose of AEF-IC-1..IC-5; not a viable answer for the arc

---

## What would resolve this

This inception resolves through **operator dialogue** (not code spikes). Four questions need answers:

**IW-1 (proof shape):** Which candidate wins? Leading candidate: Candidate 3 (hybrid). Needs operator confirm of the false-disjoint risk tolerance.

**IW-2 (declaration enforcement):** When does the orchestrator enforce the `artifactWrites` declaration requirement? Options:
  - At task-create time (lint gate)
  - At dispatch time (blocking gate — compatible with conservative-at-launch)
  - At audit time only (advisory)
  - Combination

**IW-3 (serialization trigger):** What exactly triggers serialization?
  - Non-empty glob intersection (definite)
  - Missing declaration on either task (conservative: yes; permissive: treat as disjoint)
  - `depends_on` ordering: if Task A declares `depends_on: [T-B]`, it cannot dispatch in parallel with T-B — ordering encodes a serialization requirement

**IW-4 (false-disjoint mitigation):** What prevents a task from declaring incorrect (too-narrow) `artifactWrites` globs? Options:
  - Reviewer static scan: `fw reviewer T-XXX` checks if declared globs plausibly cover the task body
  - Post-execution audit: compare declared vs actual writes (requires write-observation tooling — out of scope for conservative-at-launch but viable for v2)
  - No mitigation: accept false-disjoint as an author-discipline problem, treat incidents as learnings

---

## Go/No-Go Criteria

**GO if:**
- IW-1 pinned (one proof shape chosen with operator rationale)
- IW-2 pinned (declaration enforcement timing chosen)
- IW-3 pinned (serialization trigger list finalised)
- IW-4 acknowledged (mitigation approach chosen, even if "no mitigation for v1")
- Decision captured in `## Decisions` on the task + Dialogue Log below

**NO-GO if:**
- Dialogue surfaces that the static-declaration approach is unworkable (e.g., the codebase has too many "write anywhere" tasks) — would kick to a different proof shape or defer the arc
- Glob intersection check turns out to be ambiguous enough that it cannot reliably detect overlap

---

## Scope Fence

**IN scope:** proof shape, enforcement timing, serialization trigger, false-disjoint mitigation strategy (v1)

**OUT of scope:**
- `fw write-set check` implementation → separate build task post-GO (note: `fw write-set check` already exists at `bin/fw`; check `fw write-set check --help` before assuming it needs to be built)
- Yield-point granularity → AEF-IC-1 (T-2323)
- Sidecar listener design → AEF-IC-4
- Active-dispatcher RPC shape → AEF-IC-3
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
