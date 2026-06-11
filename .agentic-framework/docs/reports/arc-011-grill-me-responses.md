# arc-011 grill_me primary_target responses

**Task:** T-2325 (agent-side prep, no source change)
**Arc:** arc-011 parallel-execution-aef
**Companion ADR:** `docs/architecture/parallel-execution-aef.md`
**Source-of-truth:** `.context/arcs/parallel-execution-aef.yaml` `grill_me.primary_targets`
**Written:** 2026-06-11 (agent-prep for operator's next grilling session)
**Posture:** answers derive from existing ADR decisions and the T-2303 scoping
artifact. No new architecture proposed. No downstream inceptions filed.

---

## Intent

The arc-011 grill_me block names four sharpening questions that gate further
downstream inceptions from re-litigating settled forks. Until they have substantive
agent-side responses, operator-grill sessions start cold — the operator has to
re-derive AEF-ADR positions in dialogue, and downstream inceptions (IC-3/IC-4/IC-5)
risk being filed before §6 questions resolve. This artifact answers each grill_me
target so the operator can grill *the answer*, not the blank.

§ACD discipline: these are responses to grills, not decisions. The operator owns
go/no-go on every recommendation here. The `## Recommendation` block at the bottom
of T-2325 names this explicitly.

---

## 1. Headline mechanic — CONSUMER-SIDE or SUBSTRATE-TERRITORY?

**Grill (verbatim from arc-011.yaml):**
> "Is the headline_mechanic above a CONSUMER-SIDE mechanic (what AEF agents do) or
> does it cross the seam into substrate territory (what TermLink delivers)?
> §ACD/G-062 demands user-observable, not substrate-only."

**Current headline_mechanic** (`.context/arcs/parallel-execution-aef.yaml:10-15`):
> "two agents on disjoint-write-set tasks run concurrently against shared substrate,
> integrate results through the hub's serialized integration queue, and the operator
> observes both wire-evidence of parallelism (two dispatch IDs in flight at once in
> dispatches.jsonl) and the absence of governance-plane corruption (no .tasks/ or
> .context/audits/ merge conflicts) — wire-evidence-X to be sharpened by T-2303 Spike 1"

**Classification:** **CONSUMER-SIDE** with one in-text substrate reference that is
load-bearing-but-non-territorial.

**Argument by phrase:**

- "two agents on disjoint-write-set tasks run concurrently" — CONSUMER. AEF agents
  performing parallel work on AEF tasks. AEF-ADR §2 ("unit of parallelism is tasks
  with disjoint write-sets") is the consuming layer's policy decision.
- "against shared substrate" — REFERENCE. Names the substrate; does not depend on
  validating any substrate behavior. The headline_mechanic could survive substituting
  any concrete shared transport here (TermLink, NFS-mounted dir, etc.).
- "integrate results through the hub's serialized integration queue" — CONSUMER-SIDE
  POLICY, SUBSTRATE-OWNED MECHANISM. The choice to serialize integration is AEF's
  (§4 of AEF-ADR — "completed work is integrated through a serialized integration
  queue at the hub, not self-merged by agents"). The queue's *implementation* is
  substrate territory, but the *user-observable outcome* (no merge conflicts in
  .tasks/) is AEF-plane.
- "operator observes wire-evidence of parallelism (two dispatch IDs in flight at
  once in dispatches.jsonl)" — CONSUMER. `.context/dispatches.jsonl` is the
  AEF/orchestrator dispatch ledger (T-1687 substrate inside *this* repo, not
  TermLink). The operator opens AEF's own file.
- "absence of governance-plane corruption (no .tasks/ or .context/audits/ merge
  conflicts)" — CONSUMER. `.tasks/` and `.context/audits/` are AEF's governance
  ledger. The user-observable outcome is in AEF's filesystem.

**§ACD/G-062 verdict:** the headline_mechanic passes. The user-observable outcome
("operator opens dispatches.jsonl, sees two open rows; operator opens .tasks/,
sees no merge conflict markers") is wholly in the AEF/operator surface. The
substrate citation ("integrate results through the hub's serialized integration
queue") is a forced *implementation reference* — the substrate ships the queue,
but the AEF-plane behavior the operator validates is AEF-plane.

**What *would* fail §ACD/G-062:** A headline_mechanic of the form "TermLink's
serialized integration queue serves two concurrent producers correctly with no
out-of-order writes." That mechanic is wholly substrate-territory — the user
cannot observe it from AEF; only TermLink's internal logs witness it. The current
mechanic does not say that. It says "two AEF agents do parallel work and the AEF
filesystem stays clean." That is consumer-side.

**Sharpening recommendation (optional, operator's call):** strike the words
"against shared substrate" entirely — they add no §ACD value and dilute the
consumer-side framing. Result reads:
> "two agents on disjoint-write-set tasks run concurrently, integrate results
> through the hub's serialized integration queue, and the operator observes ..."

The reference to "the hub's serialized integration queue" stays because it names
the *AEF-policy choice* (serialize, not self-merge) which IS consumer-side
even though the queue itself is substrate-implemented.

---

## 2. Wire-evidence-X falsifiability — Spike 1 sharpening

**Grill (verbatim):**
> "Wire-evidence-X needs sharpening (Spike 1). 'two dispatch IDs in flight at once'
> and 'absence of .tasks/ merge conflicts' — is this actually falsifiable, or does
> it need a concrete test scenario with named tasks and a captured dispatches.jsonl
> excerpt?"

**Verdict:** the claim *is* falsifiable in principle, but the current phrasing is
under-specified on two axes — what "in flight at once" means as a wall-clock
predicate, and what counts as the "absence of merge conflicts" check. Below are
three concrete test scenarios at increasing falsifiability strength.

### Scenario 1A — Positive parallelism evidence (the happy path)

**Setup.**
- File two AEF tasks with explicit disjoint write-sets:
  - `T-PAR-A` — frontmatter `write_set: [docs/reports/T-PAR-A.md]`, body: "write
    docs/reports/T-PAR-A.md with the single line 'A ran'"
  - `T-PAR-B` — frontmatter `write_set: [docs/reports/T-PAR-B.md]`, body: "write
    docs/reports/T-PAR-B.md with the single line 'B ran'"
- Orchestrator dispatches both via `fw resolver dispatch T-PAR-A build` and
  `fw resolver dispatch T-PAR-B build` within a 5-second wall-clock window.

**Captured evidence (`.context/dispatches.jsonl`):**
```jsonl
{"dispatch_id":"D-001","task_id":"T-PAR-A","started_at":"2026-06-11T12:00:00Z","status":"in_flight"}
{"dispatch_id":"D-002","task_id":"T-PAR-B","started_at":"2026-06-11T12:00:03Z","status":"in_flight"}
{"dispatch_id":"D-001","task_id":"T-PAR-A","completed_at":"2026-06-11T12:00:45Z","status":"completed","exit_code":0}
{"dispatch_id":"D-002","task_id":"T-PAR-B","completed_at":"2026-06-11T12:00:48Z","status":"completed","exit_code":0}
```

**Falsifiable predicate (the assertion):**
- `D-001.started_at < D-002.started_at < D-001.completed_at` — proves their runtime
  windows overlap (D-002 started while D-001 still running).
- Both `exit_code: 0` — proves no governance-plane corruption tripped the worker.
- `git -C .tasks/ status --porcelain` after both complete returns no merge conflict
  markers (`UU`/`AA`/`DD` entries). This is the "absence of corruption" check made
  concrete: a `porcelain` shape check is a deterministic grep, not a human judgment.

**Why this is falsifiable:** if the orchestrator serialized the two tasks
(D-002.started_at >= D-001.completed_at), the runtime overlap window collapses
and the wire-evidence is *missing* — predicate fails, mechanism didn't fire.

### Scenario 1B — Negative case (overlap detection — the gate)

**Setup.**
- File two tasks with deliberately overlapping write-sets:
  - `T-COL-A` — frontmatter `write_set: [docs/SHARED.md]`
  - `T-COL-B` — frontmatter `write_set: [docs/SHARED.md]`
- Orchestrator inputs both for dispatch.

**Expected behavior:** orchestrator refuses to dispatch them in parallel and
emits one of two observable outcomes:
1. Serialized dispatch (D-002.started_at >= D-001.completed_at).
2. Rejection at submission (T-COL-B never enters dispatches.jsonl until T-COL-A
   completes).

**Falsifiable predicate:** parse dispatches.jsonl for the (T-COL-A, T-COL-B) pair;
their started_at/completed_at intervals must not overlap. If they do, the
disjointness gate failed — the mechanism is broken.

**Why this is the gate, not the mechanism:** Scenario 1A shows the mechanism *can*
fire correctly when disjointness holds. 1B shows the mechanism *refuses to fire*
when disjointness does not hold. Together they bracket the orchestrator's policy.

### Scenario 1C — Adversarial collision (the catastrophic case)

**Setup.**
- Bypass the orchestrator entirely. Manually invoke two parallel workers, each
  writing the same file (`docs/SHARED.md`), via direct shell — simulating a
  governance-bypassed dispatcher.

**Expected behavior:** the integration queue at the hub serializes the writes
but produces a *visible* merge conflict in the file (one worker's write wins,
the other generates a conflict marker OR the integration queue rejects the
second-to-arrive with an observable error in `dispatches.jsonl.outcomes`).

**Falsifiable predicate:** `git -C .tasks/ status --porcelain` returns at least one
conflict marker (`UU docs/SHARED.md`) OR `fw outcome read D-LATEST` returns a
failed outcome with category `governance-corruption`.

**Why this matters:** the headline mechanic claims "absence of corruption" as
positive evidence. Scenario 1C proves the *detection mechanism* exists — that
when corruption *would* occur, AEF observes it rather than silently absorbing
it. This is the §3 conservative-launch CSMA/CD argument made concrete: the
orchestrator's refusal in 1B is honour-system; 1C verifies the failure mode
the honour system protects against is actually detectable post-hoc.

### Spike 1 recommendation

The wire-evidence-X claim is currently a description ("two dispatch IDs in
flight, no merge conflicts"). To make it a *test*, the orchestrator-graph spike
in T-2303 IW-3 (or a sibling spike under T-2324's AEF-IC-2 build slice) should:

1. **Define the dispatches.jsonl row schema** that lets Scenario 1A's predicate
   parse cleanly. The current `.context/dispatches.jsonl` already has
   started_at/completed_at fields (T-1687 v1 substrate); the spike confirms they
   are sufficient OR proposes additions.
2. **Add Scenario 1B as a regression test** in `tests/integration/` or
   `tests/playwright/` — file two write-set-colliding tasks against a test
   orchestrator instance, assert serialization.
3. **Defer Scenario 1C** to the substrate-side spike that validates the hub's
   integration queue rejects out-of-order writes. AEF can ship 1A+1B without 1C
   (single-host parallel — see §3 below).

---

## 3. A2-fails — AEF-side prep if substrate blocks indefinitely

**Grill (verbatim):**
> "If TermLink-side substrate work blocks indefinitely (A2 fails), can arc-011 still
> progress AEF-side preparation (orchestrator-graph spike, harness yield-point spike)
> without committing to a contract that may not land?"

**Verdict:** yes, the substantial majority of arc-011 work is AEF-side and can
ship without any TermLink substrate primitive. The substrate-bound portion is
the *scale-up* path (multi-host parallelism on ring20), not the *headline
mechanic* (which is single-host).

### Workstreams that ship AEF-only

1. **Orchestrator-graph spike (T-2303 IW-3, still operator-deferred).** Build the
   in-memory task-graph + dispatch decision logic. Inputs: `depends_on` and
   `write_set` frontmatter fields read from `.tasks/active/*.md`. Output: a
   sequence of dispatch calls. No substrate primitive required — the graph is
   pure AEF data + pure AEF logic.

2. **Harness yield-point spike (T-2323 AEF-IC-1).** Instrument the existing
   `agents/dispatch/` script (or write a new wrapper) to check a local flag file
   between tool calls. Local flag file == `.context/working/.dispatch-flag` —
   no substrate. The spike validates the §5 cooperative-poll mechanism on one
   host, where the "sidecar" can be a `fw notify` cron that writes the flag on
   external events.

3. **Disjoint-write-set policy spike (T-2324 AEF-IC-2).** Build a static
   validator that reads `write_set:` from two task frontmatters and reports
   overlap. Pure file parsing. No substrate. This is the "static declaration"
   candidate from T-2324's Problem Statement; the spike answers whether
   frontmatter-declared write_sets are accurate enough at filing time.

4. **Single-host parallel demo (the headline_mechanic on one host).** Run two
   `claude -p` workers concurrently from one operator machine, dispatched by a
   local orchestrator script. Hub-side "integration queue" replaced by serial
   `git pull` from a shared local repo. This satisfies the *full* headline
   mechanic as written — operator sees two dispatch IDs in flight in
   `.context/dispatches.jsonl`, .tasks/ stays clean, no substrate primitive
   was used.

5. **Observability — `fw orchestrator parallel` view (extends T-1687 substrate).**
   A read-only Watchtower page that filters `dispatches.jsonl` for in-flight
   rows and shows them side-by-side. Pure read of an existing file. No substrate.

6. **Disjointness gate — orchestrator pre-flight (extends T-1687 dispatch
   envelope assembly).** Before emitting a dispatch envelope, the orchestrator
   reads the target task's `write_set:` and refuses if it overlaps with any
   currently-in-flight dispatch. Lookup: scan `dispatches.jsonl` for rows
   without `completed_at`, read their tasks' `write_set:`, compare. Pure
   AEF data + pure AEF logic.

### Workstreams that genuinely need the substrate

- **Multi-host parallelism on ring20.** Needs claim/exclusive-delivery,
  idle/busy registry, pull/assign verb. Without these, two operator hosts
  can both dispatch the same task — the dual-spoke problem the AEF-ADR §4
  derivation rests on.
- **Cross-host integration queue.** Single-host can use local `git` serial
  pushes; multi-host needs the hub's "I see all incoming branches" property.
- **Heartbeat-based agent deafness detection (§5 sidecar).** Single-host can
  use a local timestamp file; cross-host needs the TermLink presence channel.

### Recommendation for arc-011

Treat arc-011 as a **two-milestone arc**:

- **M1 — single-host parallel + headline_mechanic demo.** All six workstreams
  above. Closeable without substrate primitives. Fires the headline_mechanic
  literally as written. Estimate: 4-6 build tasks.
- **M2 — ring20 multi-host scale-up.** Cross-host parallel via TermLink
  primitives. Bound to substrate ETAs.

This is the §ACD escape from the "indefinite block" risk: M1 closure proves
the consumer-side mechanic; M2 is a sequel arc (or a milestone within arc-011)
explicitly bound to substrate progress.

---

## 4. §9 closure binding — is arc-011 cross-repo ETA bound?

**Grill (verbatim):**
> "Does §9 collaboration seam producer ≠ judge mean arc-011 closure literally
> cannot land until TermLink-side substrate primitives are validated by AEF —
> i.e. arc-011 is bound to a cross-repo arc whose ETA is partly outside our
> control?"

**Verdict on the literal question:** as currently scoped (one arc covering both
single-host and multi-host), yes — arc-011 closure is cross-repo bound, because
the §9 invariant ("AEF signs off each delivered primitive as actually usable")
requires AEF to validate substrate primitives that haven't shipped yet.

**Structural counter (recommendation):** the milestone split from §3 above
*untangles* the binding. After the split:

- M1 closure depends only on AEF-side primitives (write_set parsing,
  dispatches.jsonl, local orchestrator). AEF-controlled ETA.
- M2 closure depends on substrate primitives + AEF sign-off. Cross-repo
  ETA-bound by design (this is correct — multi-host *should* be substrate-
  gated).

**Verbatim §9 quote** (AEF-ADR `parallel-execution-aef.md` lines 247-252):
> "Strict star; coordination via persistent hub topics, never direct channels.
> Spokes never write the governance ledger directly. Conservative launch;
> landing write-observation does not by itself enable optimistic — the flip
> is a separate gated decision. Deterministic sidecar with no language-model
> call; no terminal injection for delivery; safe-degrade on deafness..."

**Verbatim §8 quote** (lines 234-244, the producer ≠ judge clause):
> "Per the substrate document's collaboration seam, it does not guess the
> shape of these primitives or wait on their implementation — it builds to
> the contract — and it **signs off** each delivered primitive as actually
> usable for dispatch before accepting it (producer ≠ judge: the consumer
> that can see the need validates the producer's output)."

**Reading.** The §8 sign-off clause is a *quality gate*, not a *closure
prerequisite*. It says: when a substrate primitive ships, AEF must validate
it. It does *not* say arc-011 stays open until all substrate primitives ship.
The current arc-011 phrasing conflates the two — the milestone split makes
the distinction structural.

**Two alternatives to the milestone split (and why they're worse):**

- **A) Wait for substrate.** Park arc-011 in-progress indefinitely. Risk: the
  AEF-side workstreams (T-2323/T-2324 spikes) become stale because the
  context they were filed in (cross-repo binding live) decays. Closure
  recedes; episodic memory of *why* the spikes were filed corrodes.

- **B) Close arc-011 on partial evidence.** Close arc-011 when the headline
  mechanic fires on single-host even though M2 hasn't started. Risk: future
  agents read "parallel-execution-aef arc closed" and assume multi-host
  works. Misleading closure state.

The milestone split (M1 = AEF-only closeable; M2 = substrate-bound, separate
arc-011-extension or sibling arc) preserves both signals — M1 closes when its
work is done, M2 stays open with its substrate dependencies visible.

**The §ACD answer to the original question:** yes, *as scoped today* arc-011 is
cross-repo bound. The recommendation is to rescope arc-011 so it isn't —
specifically, fold M1 (single-host) into arc-011's primary closure criterion
and split M2 (multi-host) into a clearly-marked subsequent milestone or
sibling arc. The operator's call: take the milestone split, or accept the
cross-repo binding.

---

## Cross-references

- AEF ADR: `docs/architecture/parallel-execution-aef.md` (§2-§9)
- Substrate ADR: `docs/architecture/parallel-execution-substrate.md`
  (TermLink-authoritative reference copy in this repo)
- Scoping inception: `.tasks/completed/T-2303-scoping-inception--parallel-execution-ar.md`
- Downstream inceptions (operator-parked):
  - `.tasks/active/T-2323-aef-ic-1-yield-point-granularity-substra.md`
  - `.tasks/active/T-2324-aef-ic-2-disjoint-write-set-policy.md`
- Arc index: `.context/arcs/parallel-execution-aef.yaml`

## What this artifact deliberately does NOT do

- Does NOT file IC-3/IC-4/IC-5 downstream inceptions. The grill_me targets do
  not name new inception scope; they sharpen existing ones. Filing more
  inceptions before §6 questions resolve is the cluster-bombing anti-pattern
  T-2303's grill page warned against.
- Does NOT propose source changes. The headline_mechanic, ADR §sections, and
  arc-011 yaml are unchanged. The "sharpening recommendation" in §1 is
  optional — operator's call.
- Does NOT update arc-011.yaml.grill_me.primary_targets. The grill questions
  remain as they were filed; this artifact answers them. Updating the
  questions is the operator's decision after grilling these responses.
