# T-3005 — Critical review of the T-3004 RCA, and a control architecture

**Status:** findings complete
**Filed:** 2026-08-15
**Predecessor:** T-3004 (decided GO 2026-08-15T05:29Z)
**Workflow:** inception

The operator asked for two things: *critically review the RCA*, and *devise means
for reliability and antifragility — stays fresh, is online, is being used, issues
detected and mitigated*. Part 1 is the critique. Part 2 is the design, and it is
shaped by what the critique found rather than by T-3004's slice list.

---

# Part 1 — Critical review of the T-3004 RCA

Five defects. Three change the conclusion.

### C1 — "Runs on every task start" was inferred from code, never observed. It is false.

T-3004 asserted the recall path runs at every `fw context focus`. That came from
reading `focus.sh:144,152`, not from watching it. Measured:

```
$ python3 lib/ask.py --concise --no-think "Brief me on task T-3005..."
rc=1  elapsed=1s  stdout=0 bytes
Ollama embed error: server busy, please try again.
  maximum pending requests exceeded (status code: 503)
Traceback (most recent call last): ...
```

It does not run. It **crashes in one second**, and `2>/dev/null || true` erases
both the traceback and the exit code. Three `work-on` invocations in this session
each printed *Related knowledge* and no *Task Briefing* — the evidence was on
screen the whole time T-3004 was being written, and I read past it.

**And the visible recall is not the vector store at all.** `memory-recall.py` —
the thing that produced "Related knowledge: L-019, L-349…" — imports `yaml` and
`re` and reads `.context/project/learnings.yaml`. Keyword matching over YAML. It
has no connection to sqlite-vec.

So T-3004 conflated two independent paths and credited the working one's output to
the broken one. **What actually functions today is non-semantic.**

### C2 — One root cause was offered for a two-cause outage

T-3004 named `embeddings.py:206` and stopped. Stopping at the first sufficient
cause is the classic RCA error, and here it hid an entirely separate live fault:

**Second root cause — model-slot contention.** `OLLAMA_MAX_LOADED_MODELS=1`, and
the slot is held by `gemma4:latest` (11 GB VRAM, `/api/ps`). The embedding model
`nomic-embed-text-v2-moe` is a *different* model, so every embed request needs an
eviction, queues behind `OLLAMA_NUM_PARALLEL=3`, and 503s. Persistent, not
transient: 3/3 probes failed.

**Why it never clears — and this is the finding that relocates the isolation
question.** The lease is not merely held, it is continuously renewed: observed
expiry moved 07:49:44 → 07:53:12 while probing. The renewals are not ours.

```
OLLAMA_HOST=0.0.0.0:11434     # every interface, no auth
OLLAMA_KEEP_ALIVE=30m         # each use renews a 30-minute lease
OLLAMA_MAX_LOADED_MODELS=1    # one model, fleet-wide

clients: 127.0.0.1 ×20 | .107 (us) ×6 | .170 ×4 | .171 ×3 | .129 ×1
```

**The embedding provider is an unauthenticated fleet-shared singleton with one
model slot.** Three other hosts hold live connections to it. Any one of them
keeping a chat model warm renews the lease indefinitely and permanently starves
every embedding consumer on every project — with no quota, no priority, and no
attribution.

So the operator's isolation question has a real target after all; T-3004 looked at
the wrong layer. The *store* is isolated per-project and needs nothing. The
*provider* is not isolated at all, and that is what is actually broken. This also
inverts T-3004's tidy conclusion that the framework's §TermLink shared-substrate
reasoning does not apply here: it applies squarely to Ollama, and the sharing is
unmanaged.

These two causes are independent and need different fixes. Fixing `:206` alone
would rebuild the index and change nothing observable, because the embed path
would still 503 — a repair that reads as complete and delivers nothing.

**And `:206` itself is a symptom.** T-395 introduced `STALE_SECONDS` (*"rebuild if
older than 1 hour"*) **and** the reuse branch (*"avoid expensive full rebuild on
every search"*) in the same change. Those intents contradict; the reuse branch
won. The transferable root cause is one level up:

> A performance fix silently disabled the freshness capability sitting next to it,
> and nothing detected the loss of a capability.

That is the same class as L-352 / G-064 (zero-consumer substrate hidden five
months) and the same class as this session's T-2999/T-3000 false greens.

### C3 — "15% recall" describes a ceiling, not the current state

Current effective semantic recall is **0%**. Nothing can be retrieved while every
embedding request 503s. 15% is what recall would return *if the provider were
healthy*. T-3004 stated the ceiling as the state.

### C4 — "Actively misleading recall" was a hypothesis presented with the confidence of a finding

T-3004 implied the ancient 15% would surface superseded patterns. Tested by SQL
(no embedding needed):

| probe | hits |
|---|---:|
| `"Safe pattern"` (the label T-3000 deleted) | 0 |
| `worktree` | 0 |
| `fw integrate` | 0 |
| `master-merge-only` | 0 |
| `arc_id` | 0 |
| `BVP` | 0 |
| `headline_mechanic` | 0 |

**Partly retracted.** The index does not contain contradicted guidance; it
contains *nothing* about the subsystems that now dominate the framework. The harm
is omission, not contradiction.

The residual concern survives in weaker form and should be stated as the
hypothesis it is: nearest-neighbour retrieval always returns *something*, so a
query about worktrees returns whatever is closest in embedding space — unrelated
old content — which an LLM then writes a confident briefing over. Omission at the
index becomes fabrication at the output. Measured: the omission. Not measured: the
downstream effect.

### C5 — The proposed fix depended on the field the same document had just discredited

T-3004 slice 2 proposed a doctor rail on "index age" three paragraphs after
establishing that `built_at` reports open time. The plan contradicted its own
finding. Corrected in Part 2: the freshness signal must not read `built_at`.

### What T-3004 got right

The topology answer holds and is worth restating because it survived scrutiny:
the store is per-project by construction, isolation is already the architecture,
and migration is a no-op. Coverage arithmetic and the `:206` mechanism are both
correct as far as they go. The failure was stopping there.

### Revised causal chain

```
Semantic recall has been dead, and nobody knew
├── (a) index frozen since 2026-03-10 → 15% ceiling
│      └── STALE_SECONDS unreachable (:206 reuse path stamps the clock)
│            └── T-395 perf fix disabled the freshness capability beside it
│                  └── no control asserted the capability still existed
└── (b) every embed request 503s → 0% actual
       └── MAX_LOADED_MODELS=1; chat model holds the only slot
             └── embed and chat treated as interchangeable consumers of one resource

both invisible because:
  is_index_ready() counts rows, not correspondence
  built_at reports open time as build time
  no doctor/audit rail exists
  focus.sh discards stderr AND forces exit 0
  the output is generated prose — plausible whether or not retrieval worked
```

The last line is the deepest one. **A substrate whose output is generated prose
cannot be monitored by looking at its output.** Every instrument here failed the
same way — by being unable to go red. That is what the controls must fix.

---

# Part 2 — Control architecture

Four properties were asked for. Each needs its own signal; none substitutes for
another.

### Design constraints (learned from Part 1)

1. **No control may depend on `built_at`** (C5).
2. **Presence ≠ freshness ≠ liveness ≠ usage.** Four checks, because in Part 1
   each failed independently while the others read fine.
3. **Every control must be watched failing before it counts.** Every instrument
   T-3004 examined was green-by-construction. A control not yet observed red is a
   hypothesis.
4. **Expected-degraded is a first-class state** (IW-6). A fresh consumer with no
   index is not a fault. If every task start in every consumer warns, someone
   re-adds `2>/dev/null` and we regress to exactly here. Three states: `OK`,
   `EXPECTED-DEGRADED`, `FAULT`. Only `FAULT` is loud.

### The four signals

| Property | Signal | Mechanism | Fails red when |
|---|---|---|---|
| **Fresh** | corpus coverage % + age | `corpus_manifest` table written at reindex: per-category file count, max mtime, corpus hash. Doctor recomputes and diffs. | index misses >N% of corpus, or oldest-vs-newest gap exceeds threshold |
| **Online** | typed liveness probe | tiny fixed-input embed call, classifying: `ollama-down` / `model-absent` / `503-contention` / `ok` | any non-`ok`, with the class named |
| **Used** | query telemetry | append-only `.context/working/recall-telemetry.jsonl`: ts, query hash, n_hits, top_score, latency, outcome | zero rows in 7 days (the G-064 zero-consumer signal) |
| **Correct** | canary | reindex inserts `FWCANARY-<epoch>`; health check must retrieve it semantically and match the current epoch | index stale, index absent, or embed path broken — one binary check |

The **canary is the keystone**. It is the only one that exercises the full path
end-to-end — embed → store → retrieve — and it converts unfalsifiable prose into a
binary. It also subsumes the others as a smoke test, which is why it is worth
building first even though it looks like the least of the four.

### Mitigations, per fault class

- **`503-contention`** (live now): embedding is a small latency-sensitive model
  that must not queue behind an 11 GB chat model whose lease three other hosts
  keep renewing. Options, cheapest first:
  - (i) **`OLLAMA_MAX_LOADED_MODELS=2`** — lets the embed model co-reside.
    One config change. Gated on a VRAM headroom check (gemma4 alone occupies
    11 GB; total capacity not yet measured — do that before changing it).
  - (ii) **Pin the embed model** with `keep_alive: -1` on embed requests, so it
    cannot be evicted by chat traffic.
  - (iii) **Bounded retry with backoff** in `_embed`. Needed *regardless* of
    (i)/(ii): today a single transient 503 destroys an entire briefing with no
    retry and no trace.
  - (iv) **A project-local embed instance on its own port** — the only option
    that is genuinely isolated from fleet traffic, and the only one that survives
    another host changing its behaviour. Costs VRAM and an extra process.

  (iii) is unconditional. (i)+(ii) are the cheap mitigation. (iv) is the real
  isolation fix and should be decided on evidence from how often (i)+(ii) hold.

  **Cross-host caveat (§Gap Homing, T-1333):** the contention originates on
  `.170`/`.171`/`.129`, which this repo does not own. Options (ii)–(iv) are fixes
  we can land unilaterally; anything that asks other hosts to behave differently
  belongs filed where those hosts are governed, not here.
- **Staleness**: incremental reindex on a schedule. Must follow the full
  registry → generated → deployed chain (L-364) — a cron entry that is "wired" is
  not deployed.
- **Consumers have no index**: build on `fw init` / `fw upgrade`.
- **Silent caller**: `focus.sh` classifies instead of discarding — `OK` prints the
  briefing, `EXPECTED-DEGRADED` prints one dim line, `FAULT` prints the class and
  the remedy.
- **Isolation fail-open** (T-3004 D-A): refuse rather than default to
  `_FRAMEWORK_ROOT`; pass `PROJECT_ROOT` explicitly in `.mcp.json`.

### What makes this antifragile rather than merely monitored

Monitoring detects. Antifragility requires failures to become inputs:

1. **Misses drive reindex priority.** A recall returning 0 hits or a top score
   below threshold logs the query. Repeated misses on a topic are evidence that
   region of the corpus is unindexed — the reindexer reads the miss log and
   prioritises it. The system indexes what is actually being asked for.
2. **Misses are also corpus-gap evidence.** If agents repeatedly ask about
   something and the corpus genuinely has nothing, that is not a cache miss — it
   is a documentation gap, and it belongs in the observation inbox rather than in
   a retry loop. Distinguishing the two requires the telemetry in the table above.
3. **Repeat-class faults escalate themselves.** Same fault class N times in a
   window auto-registers a concern, per the Error Escalation Ladder. Level A→D
   without a human having to notice a pattern across months — which is precisely
   what did not happen here.
4. **The canary is deliberately broken once**, in a test, and asserted red. A
   positive control nobody has watched fail is a hypothesis (constraint 3).

### Sequencing

Ordered by *evidence produced per unit of work*, not by depth:

| # | Slice | Why here |
|---|---|---|
| 1 | Liveness probe + embed-path availability (retry, pin, VRAM-gated slot change) | Restores recall from 0%. Everything else is unobservable until embedding works. |
| 2 | Canary + `corpus_manifest` | The keystone control; makes 3–6 verifiable |
| 3 | Fix `_get_db()` freshness (T-3004 slice 1) | Root cause (a) |
| 4 | Doctor/audit rail on manifest + canary + tri-state | Detection, using signals that can go red |
| 5 | Scheduled incremental reindex (L-364 chain) | Standing property |
| 6 | Telemetry + miss-driven priority + escalation | The antifragile half |
| 7 | Consumer bootstrap; fail-closed `PROJECT_ROOT` | T-3004 D-A/D-B |

Slice 1 is the only one that changes anything a user can feel today. Slices 1+2
together are the minimum honest stopping point: recall works, and a control exists
that will go red when it stops working.

### Amendment — the embedding model decision must precede slice 2 (T-3007)

Research supplied by the operator after this design was written argues for
replacing `nomic-embed-text-v2-moe`. Captured and critiqued in
`docs/reports/T-3007-embedding-model-and-adaptation.md`. One consequence lands
directly on this sequencing and is recorded here rather than there:

`web/embeddings.py:211` binds the vec0 virtual table to `EMBEDDING_DIM` (`:76`),
so **any model with a different output dimension forces a schema migration and a
full re-embed** — which slices 3 and 5 already owe. Two facts follow:

1. **Do the switch with the reindex, not after it.** Together they cost one
   reindex; apart they cost two.
2. **Slice 2's thresholds must be calibrated against the model we intend to
   keep.** The canary threshold and the coverage/score rails encode assumptions
   about what a good similarity score looks like. Calibrate on the old model,
   swap, and every threshold needs revisiting — with the controls themselves now
   suspect, which is the failure mode this whole arc exists to prevent.

So the model decision (T-3007 steps A and B) is a **prerequisite of slice 2**, not
a parallel track. Slice 1 is unaffected and stands as landed.

---

## Recommendation

**Recommendation:** GO — sequence above, slice 1 first and separately.

**Rationale:** The critique found that T-3004's headline fix would have shipped a
repair with no observable effect: rebuilding the index while every embed request
503s changes nothing, and the completion gate would have passed it. That is the
same false-green class the fix is meant to end. Slice 1 restores the substrate
from 0% and is a config change plus a retry; it should land and be verified before
anything downstream is built on the assumption that retrieval works. GO is on the
sequence, not on the whole list as a batch.

**Evidence:**
- Briefing path measured: rc=1 in 1s, `503 maximum pending requests exceeded`, 3/3
  probes — not a timeout, a hard failure, fully swallowed by `2>/dev/null || true`
- `memory-recall.py` imports `yaml`/`re` and reads `learnings.yaml` — the visible
  recall is keyword matching, not the vector store
- `/api/ps`: `gemma4:latest` holds the single slot; `OLLAMA_MAX_LOADED_MODELS=1`,
  `OLLAMA_NUM_PARALLEL=3`
- SQL probes: 0 hits for worktree / fw integrate / arc_id / BVP / headline_mechanic
  — and 0 for the superseded label too, which partly retracts T-3004's harm claim
- T-395 introduced `STALE_SECONDS` and the reuse branch that defeats it in one
  change
- `OLLAMA_HOST=0.0.0.0`, `KEEP_ALIVE=30m`, `MAX_LOADED_MODELS=1`; clients from
  `.170` ×4, `.171` ×3, `.129` ×1 — the lease is renewed by hosts we do not own,
  observed extending 07:49:44 → 07:53:12 mid-investigation

**NO-GO, carried forward from T-3004:** migrating the *store* to per-project or
server-backed storage. Unchanged — it is already per-project.

**Amendment to T-3004's isolation verdict.** T-3004 concluded isolation was a
solved non-question. That was right about the store and wrong about the system.
The embedding provider — the component without which the store is inert — is an
unauthenticated fleet-shared singleton with one model slot, and it is the
component currently failing. **Absolute isolation, if it is wanted, belongs at the
provider, not the store.** That is a live open question (slice 1, option iv), not
a settled NO-GO, and T-3004 should not be read as having closed it.

## Dialogue Log

### 2026-08-15 — the ask

- **Operator:** "so what we then also need to do is, critically review RCA and
  devise means for reliability and anti fragility, making sure its stays fresh and
  is online and is being used and any issues are detected and mitigated"
- **Agent:** treated "critically review" as adversarial review of my own RCA
  rather than elaboration of it. Five defects found, three of which change the
  conclusion; the strongest (C1) was contradicted by output already on screen when
  T-3004 was written.

### 2026-08-15 — what the critique changed about the design

The control architecture is not T-3004's slice list reordered. C1/C2/C3 moved the
embed-path outage to slice 1 — T-3004 did not know it existed, and its slice 1
(rebuild the index) would have produced a green task and a dead substrate. C5
removed `built_at` from the freshness design. C4 downgraded a stated finding back
to a hypothesis and kept it labelled as one.
