---
task: T-2324
title: "AEF-IC-2: Disjoint write-set policy — how does the orchestrator prove disjoint write-sets before parallel dispatch?"
arc: parallel-execution-aef
status: converged
dialogue_converged: 2026-06-26
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

Session 2026-06-26 (operator + termlink-substrate-agent → AEF recording agent).

| # | Who | Exchange |
|---|-----|----------|
| 1 | substrate-agent | Surfaced that `fw write-set check` **already exists** at `bin/fw` and is consumed by "the arc-011 orchestrator (T-2337)". This contradicts the inception framing, which treats the validator as an un-built post-GO deliverable (Scope Fence already carried a hedge note to this effect at line 130). |
| 2 | operator | Course correction: *"investigate arc-011 first."* Don't re-deliberate static-vs-dynamic-vs-hybrid in the abstract — check what the arc has already shipped. |
| 3 | investigation (read-only) | Found **arc-011 ≡ `parallel-execution-aef`** — the same arc this inception belongs to (`arc_id: parallel-execution-aef`). The disjoint-write-set policy is **already built and shipped within this arc**: T-2337 (`lib/write_set.py` + `fw write-set check`, status work-completed) and T-2339 (`agents/orchestrator/orchestrator-graph.py`, status work-completed). The shipped mechanism is **static frontmatter (`write_set:`), path-level + glob-expanded, serialize-on-overlap-OR-undecidable**. |
| 4 | operator | Decision: **RATIFY the as-built static mechanism** as the policy of record for IW-1/IW-2/IW-3. Do NOT re-open the proof-shape question — the arc chose static, built it, and wired it. Document the static-vs-hybrid trade-off (fabric blast-radius predicts READS not WRITES, and drifts → at best a post-dispatch audit, never the blocking gate) as the *rationale for why static won*, not as an open question. |
| 5 | operator | IW-4 (false-disjoint mitigation) is the **one genuine forward gap**. Choose **reviewer static scan** for v1: a pre-dispatch check (`fw reviewer T-XXX`) that flags when a task's declared `write_set:` plausibly UNDER-covers its body. Under-declaration is the only dangerous error class — every other declaration error merely over-serializes (safe). Post-execution declared-vs-actual write audit is v2 (needs filesystem-write observation = substrate gap #4, out of scope for conservative-at-launch). |
| 6 | recording agent | Converged: **RATIFY-as-built + add IW-4 reviewer-scan**. Verified the as-built orchestrator (T-2339) has **no** under-declaration / false-disjoint guard (grep of `orchestrator-graph.py` and `lib/reviewer/` — zero `write_set` / `disjoint` / `under-declar` / `plausib` / `cover` detector hits). So IW-4 is **not** redundant — it is T-2324's actual contribution. |

---

## Findings

**F1 — arc-011 ≡ this arc.** `.context/arcs/parallel-execution-aef.yaml` has `id: arc-011`. The "arc-011" the substrate agent referenced and the `parallel-execution-aef` arc this inception (`arc_id: parallel-execution-aef`) belongs to are the same arc. There is no second arc to investigate.

**F2 — the policy is already built and wired (IW-1/2/3 retroactively answered).** Two completed sibling tasks in this arc's M1 milestone implement exactly the policy this inception was deliberating:
- **T-2337** (arc-011 M1 §3, work-completed) — `lib/write_set.py` + `fw write-set check <T-A> <T-B>`. `compare()` returns `disjoint` (both declared, no path overlap) / `overlap` (both declared, ≥1 shared path) / `undecidable` (≥1 task lacks `write_set:`). Globs are expanded against the working tree; unborn declared paths overlap correctly (`lib/write_set.py:14-16, 130`).
- **T-2339** (arc-011 M1 §1, work-completed) — `agents/orchestrator/orchestrator-graph.py`. Reads active-task `write_set:` frontmatter, builds the overlap graph via `write_set.compare()`, and **serializes on `overlap` OR `undecidable`** (`orchestrator-graph.py:132-133`). A task with no `write_set:` frontmatter → `undecidable` → "pre-flight skipped" → serialized, never parallel-dispatched (`orchestrator-graph.py:235-252`).

This answers the inception's three deliberated questions as built fact, not open choices:
- **IW-1 (proof shape)** → **static** frontmatter declaration. (Candidate 1, not the ADR's "leading" hybrid Candidate 3.)
- **IW-2 (granularity)** → **path-level + glob-expanded** (`.tasks/active/T-*` and source paths both supported by glob expansion).
- **IW-3 (serialization trigger)** → **`overlap` OR `undecidable`** (missing declaration is conservatively serialized); `depends_on` ordering composes on top.

**F3 — why static won (the trade-off the candidates raise, recorded as rationale).** Candidate 2 (dynamic, `fw fabric blast-radius`) and the hybrid Candidate 3 both lean on blast-radius to *predict* write-sets. But fabric blast-radius predicts **read** impact (downstream consumers via `depends_on` edges), not **write** locations, and fabric cards drift (`fw fabric drift`). A predictor that over-includes reads and can be stale is unsafe as a *blocking* disjointness gate — it would refuse safe parallels (false-overlap) and, worse, could be trusted past a real overlap if cards are stale. Static declaration with serialize-on-undecidable inverts the risk: every declaration error except under-declaration merely over-serializes (safe). Hence the arc shipped static; blast-radius is at best a **post-dispatch audit** signal, never the gate. The worked example at line 165 (static → disjoint vs dynamic → false-overlap on the shared inception-render path) is the load-bearing data point, and it resolved in static's favour.

**F4 — IW-4 is the one forward gap (T-2324's actual contribution).** Static declaration's single dangerous failure is **under-declaration** (declared `write_set:` too narrow → orchestrator computes `disjoint` → two workers collide on an undeclared shared path). The as-built orchestrator (T-2339) does **not** guard this: grep of `orchestrator-graph.py` and `lib/reviewer/` finds zero under-declaration / false-disjoint / coverage-plausibility detector. The operator chose **reviewer static scan** (`fw reviewer T-XXX`) as the v1 mitigation — a pre-dispatch check that flags when a declared `write_set:` plausibly under-covers the task body. Post-execution declared-vs-actual write audit is **v2** (requires filesystem-write observation = substrate gap #4, ruled out by the conservative-at-launch constraint).

**F5 — field-name reconciliation.** This artifact (Candidates section) and the task body's earlier framing used the assumed field name `artifactWrites`. The actual shipped frontmatter field is **`write_set:`** (the task body at line 106 already uses the correct name; the Candidates section here does not). All references to `artifactWrites` should read `write_set:`.

**F6 — process note (mild smell).** This inception was deliberating a question its own arc had already shipped a build answer for (T-2337 + T-2339 completed 2026-06-11; this inception was un-parked 2026-06-25 and still framed the validator as un-built). An inception lagging its own arc's build work is a one-line process smell worth recording — the Scope Fence already carried a hedge note (line 130: "`fw write-set check` already exists... check `--help` before assuming it needs to be built"), which is the seam where the lag was already visible.

---

## Recommendation

**Recommendation:** GO — to **RATIFY** the as-built policy (recording-only; human owns `fw inception decide T-2324 go`).

**Rationale:** The disjoint-write-set policy is not an open question — it is shipped and wired within this same arc (T-2337 validator + T-2339 orchestrator-graph). The policy of record is **as-built static**: `write_set:` frontmatter, path-level + glob-expanded, **serialize-on-overlap-OR-undecidable**. Static won over dynamic/hybrid because fabric blast-radius predicts reads not writes and drifts (so it is at most a post-dispatch audit, never the blocking gate); under serialize-on-undecidable, every declaration error except under-declaration is safe.

**Single forward addition authorised on GO:** IW-4 false-disjoint guard via **reviewer static scan** — a `fw reviewer T-XXX` detector that flags plausible `write_set:` under-coverage of a task body. This is a small build task; the as-built orchestrator (T-2339) lacks it, and under-declaration is the only un-guarded dangerous error class. Post-execution declared-vs-actual write audit is noted as **v2** (substrate gap #4 — filesystem-write observation, out of scope for conservative-at-launch).

**Evidence:**
- `lib/write_set.py:14-16,130` — `compare()` → disjoint/overlap/undecidable, glob-expanded.
- `agents/orchestrator/orchestrator-graph.py:132-133,235-252` — serialize-on-overlap-or-undecidable; no-declaration → undecidable → serialized.
- `.context/arcs/parallel-execution-aef.yaml:id: arc-011` — arc identity.
- T-2337, T-2339 both in `.tasks/completed/` (work-completed).
- grep `lib/reviewer/` + `orchestrator-graph.py` — zero under-declaration guard → IW-4 not redundant.

**Frontmatter:** status `open` → `converged`; `dialogue_converged: 2026-06-26`.
