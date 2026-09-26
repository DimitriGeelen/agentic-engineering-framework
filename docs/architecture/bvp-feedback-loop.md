# BVP feedback loop — design

**Status:** design, under T-3484. T-3482 (remove the human from scoring and from
driver approval; add telemetry) is GO, operator, 2026-09-25T21:56:30Z.
**Companion:** `docs/reports/T-3470-go-scope-candidate-triage.md` (how a flat
scorer stalls selection), `policy/value-drivers.yaml` (the rubric this loop
calibrates).

## 1. The problem, stated from measurement

Two facts from the corpus decide the shape of everything below.

**Value has never been measured here.** Zero tasks carry confirmed
`bvp_scores`. `fw bvp confirm` — documented at `lib/bvp.sh:799` as a
sovereignty boundary — has never been run to completion. So removing the human
from scoring removes nothing in practice, and there is **no historical value
label to calibrate against**.

**Cost has been measured all along, for part of the work.** ~2,988 episodics
carry a measured footprint; 817 tasks carry a cost prediction; and
`.context/dispatches.jsonl` carries `task_id` plus full token accounting
(`input_tokens`, `output_tokens`, `cache_read_input_tokens`,
`cache_creation_input_tokens`) on 1,107 of 2,565 rows.

The two axes are therefore **not symmetric and must not be built the same way**.
Cost is a calibration problem with data waiting. Value is a *construction*
problem: the signal does not exist and has to be created.

And the defect this loop exists to catch is already on record: the v1 heuristic
collapses a 39-task backlog into two near-identical score patterns, because it
reads **phrasing**. Selection stalled on it, and no human noticed — a worker
running the estimator did.

## 2. Three axes, not two

`### IW-3` established that rework and correction measure the *delivery*, not the
*idea*. A high-value feature built badly and a low-value feature built badly
score identically, and the right response differs — rebuild versus drop. So they
get their own axis rather than being folded into value.

| axis | question it answers | ground truth |
|---|---|---|
| **COST** | what did this consume | real, token-level, for dispatched work |
| **VALUE** | did this turn out to matter | none today — constructed from proxies |
| **QUALITY** | was it delivered well | derivable from the corpus |

## 3. The ledger

One append-only file: **`.context/bvp-outcomes.jsonl`**. One row per event, never
edited in place.

```jsonc
{
  "task_id": "T-3479",
  "ts": "2026-09-26T08:14:02Z",
  "phase": "predicted" | "realised" | "revisit",
  "rubric_sha": "e4a00f38e801",          // which rubric produced the prediction
  "predicted": { "D1": 4, "D2": 4, "D3": 3, "D4": 2,
                 "cost_estimate": { "blast_radius": null, "tier": 2, "effort": 8 } },
  "cost":    { "tokens_in": 0, "tokens_out": 0,
               "cache_read": 0, "cache_create": 0,
               "attributable": true, "source": "dispatches.jsonl" },
  "quality": { "rework_commits": 0, "operator_corrections": 0, "reopened": false },
  "value":   { "usage_30d": null, "peer_adoption": null, "revisit_verdict": null }
}
```

**`attributable: false` is a first-class value, not a zero.** Parent-session work
has no per-task token cost, and recording 0 would be a lie that averages into the
calibration. This is the same rule T-3068 already applies to `blast_radius`
(*unknown, not zero*), and the same rule Amendment 1 applies to ack states
(`UNKNOWN` is a valid terminal state). A loop that cannot say "I do not know"
will learn from numbers it invented.

## 4. The signals, each with its limit

### 4.1 COST — available today, no new instrumentation

**Source:** `.context/dispatches.jsonl`, joined on `task_id`.

**Known bias, now MEASURED (T-3486 backfill, last 300 completed tasks):**

| | |
|---|---:|
| attributable | **23** |
| unattributable | 277 |
| **fraction** | **7.67 %** |

**This is far starker than the row count implies.** "1,107 of 2,565 dispatch rows
carry tokens" reads as ~43 % coverage; per *task* it is **7.67 %**, because many
rows belong to the same few dispatched tasks while most completed work was done
in a parent session and cannot be attributed at all.

So the cost axis calibrates on roughly **one task in thirteen**, and that
thirteenth is not a random one — it is whatever we chose to dispatch, a set
CLAUDE.md's own table shows is skewed (inception 0 % verification pass, refactor
65 %). `attributable_fraction()` therefore returns **with every calibration**
rather than on request: a calibration that does not print its fraction beside its
result is reporting a biased estimate as a plain one.

**Gap, not solved here:** per-task attribution inside a parent session. Naming
it is the deliverable; closing it needs turn-level task attribution that does
not exist.

### 4.2 QUALITY — derivable from the corpus

| signal | source | status |
|---|---|---|
| **operator corrections** | `feedback-stream.yaml`, `kind: override_applied` | **built** (T-3497) |
| auto-ticks | `feedback-stream.yaml`, `kind: auto_tick` | **built** (T-3497) |
| follow-on defects | later **bug-class** tasks whose `related_tasks:` name it | **built** (T-3497) |
| rework commits | commits touching the task's `components:` after `date_finished` | **not built** — one `git log` per task over ~3,400 tasks is not cheap, and `components:` resolves only at close |

**CORRECTION (T-3497): this section previously claimed 1,970 correction entries.
That was wrong.** The figure came from a grep for `auto_tick|override|untick`
across the whole file, which matched payload prose. Counted by event `kind:`:

| kind | count |
|---|---:|
| `verdict_recorded` | 2326 |
| `scan_emitted` | 2326 |
| `recommendation_claims_verdict` | 130 |
| **`override_applied`** | **125** |
| **`auto_tick`** | **12** |

There is also **no un-tick event kind at all**, so the T-1985 rail this section
described — a human un-ticking an auto-tick — leaves nothing in the stream to
count. `override_applied` is still a genuine correction (someone declared a
reviewer finding wrong), but 125 across the corpus is a thin signal, not a rich
one. A signal counted the wrong way is not a smaller signal; it is a different
one.

**Measured coverage, both axes, so the sparsity is visible up front:**

| axis | tasks with any signal |
|---|---|
| COST (last 300 completed) | **7.67 %** |
| QUALITY (last 400 completed) | **4.8 %** — 2 corrections, 21 follow-on defects |

Neither axis is dense. Any calibration must report its coverage beside its
result, or it is presenting an estimate from one task in twenty as a corpus-wide
finding.

### 4.3 VALUE — constructed, because nothing measures it

**(a) Usage.** Verb-invocation counts. **built** (T-3499).

**CORRECTION (T-3499): this section previously said usage came "from
`lib/hook-telemetry.sh` and the existing counters", as though it were already
available. It was not.** That module counts **hooks, not verbs**:
`.context/working/.hook-counter` holds `check-active-task=793`,
`budget-gate=8970`, and no fw verb appears in it anywhere. A repo-wide grep for
any verb-level counter returned nothing, and `bin/fw` had no invocation telemetry
at all. Coverage was **zero, not thin** — so S6 had to start with a *writer*, not
a reader.

`bin/fw` now increments `.context/working/.verb-counter` at its single dispatch
point, before the `case` (most branches `exec`, so a counter placed after them
would never run). `hook` is excluded — already counted per-hook, and the hottest
path. Read by `lib/bvp_usage.py`. Measured cost: **+6.8 ms on a ~630 ms
invocation, ~1.1%**; `FW_VERB_TELEMETRY=0` disables it.

*Limit that must be designed around:* a verb nobody calls may be **unused** or
merely **unknown**, and the correct response differs (retire versus surface).
Usage is therefore recorded **paired with discoverability** — is the verb in
`fw help`, is it named in CLAUDE.md — so the two cases stay distinguishable.
Unpaired usage counts would retire discoverable-but-unknown features. Shipped as
three classes (`used` / `discoverable-but-unused` / `undiscoverable-and-unused`),
and only the third is ever reported as retirable.

*Second limit, inherent:* counts accumulate from first instrumentation only, so a
low count may mean a short observation window rather than low value. The reader
returns that caveat with every report. Clean baseline starts
**2026-09-26T08:41:19Z**.

### 4.3(a-bis) The pattern this correction belongs to

Four signals were specified in this document as resting on existing
infrastructure. Measured, one at a time:

| signal | infrastructure | actually fed |
|---|---|---:|
| COST — `dispatches.jsonl` | exists | yes — **7.67 %** |
| QUALITY — `feedback-stream.yaml` | exists | yes — **4.8 %** |
| VALUE/revisit — `revisit_at` + G-053 | exists | **1 of 1,196** (OBS-540) |
| VALUE/usage — `hook-telemetry.sh` | exists | **wrong subject — 0** |

Two of four were not fed. **Infrastructure existing is not the same as
infrastructure being fed**, and this document read all four as available because
it checked for the former. That is the arc's own recurring defect — *detection
exists, routing does not* — appearing inside the plan rather than inside the code.
The operative consequence is in §8: **any slice whose feed is unfed must build
the write half first**, or it ships a reader over an empty queue, which is the
arc-020 failure (capability complete, tested, never called).

**(b) Cross-agent adoption — the strongest signal available.** 832,
010-termlink and 1409-sprind vendor this framework and choose independently what
to adopt. **They have no stake in our self-assessment.** Every other signal in
this document is generated by the system being judged; this one is not. It is
the only non-circular value evidence we have.

*Mechanism:* ask them, over the sidecar rail. A consult per peer: which version
do you pin, and do you invoke verb X. This is a real use of the rail rather than
a decorative one.

*Limit:* it lags peer upgrade cadence — 010-termlink is on v1.6.29 against our
v1.7.120 — so **absence of adoption is ambiguous** between "not valuable" and
"has not upgraded yet." The peer's pinned version is therefore recorded
*alongside* the answer, so the ambiguity is visible rather than silently
resolved as a zero.

**(c) The post-implementation revisit — the keystone.** The only signal that
closes the loop on a **decision** rather than a delivery.

The corpus already shows exactly what it catches: arc-020 shipped complete,
tested, and **unused for weeks** because nothing asked "is this being called?";
185 GO-recorded inceptions whose propagation nobody checked.

*Trigger, reusing what exists:* the task template already carries
`revisit_at: YYYY-MM-DD` (T-1451, added for DEFER decisions) and G-053 already
scans it. Extend rather than invent: set `revisit_at` at close for tasks above a
value threshold, and let the existing scan surface them.

*What the revisit asks, in order:*
1. **mechanical** — has it been used since close (usage, peer adoption, commits)?
2. **operator** — did it do what it was supposed to?

Question 1 runs unattended. Question 2 is a `[REVIEW]` Human AC on a revisit
task, and it is the *only* human step in the loop.

## 5. The tension, stated deliberately (IW-6)

T-3482 removes the human from scoring at **filing** time. §4.3(c) puts a human
back at **revisit** time.

That is not the boundary creeping back. It moves the human **from predicting
value to confirming realised value** — the judgement a human is actually good
at, made against evidence instead of a blank form. Predicting is what the
scorer does badly *and* what the human never did at all (zero confirmations).

Stated here so a future reader does not discover it and infer drift.

## 6. How the loop closes

The rubric is versioned — `rubric_sha` is already stamped on every proposed
score. That is the calibration handle.

```
predict (rubric vN) ──▶ work ──▶ realised (cost/quality) ──▶ revisit (value)
        ▲                                                          │
        └────────── propose rubric vN+1 from the deltas ◀───────────┘
```

**Two rules the loop must obey, both from the standing mandate:**

1. **Calibration proposes a new rubric version; it never edits a recorded score
   in place.** Producer-not-judge: the system does not rescore its own completed
   work upward. History stays immutable, and every score remains traceable to
   the rubric that produced it.
2. **Circularity is designed out.** *"Did the task get worked"* is not a value
   signal — we rank by score and work the top, so the score caused the outcome. A
   loop trained on it converges on confirming itself. Only signals produced
   **outside** the ranking count: peer adoption, operator revisit verdict, usage
   by someone who did not file the task.

## 7. The control that replaces the removed human

The confirmation gate is being removed. Something must take its place, or D2
(*no silent failures*) is violated by construction.

**The degenerate-scorer alarm.** If a scorer's output has near-zero variance
across a task family, it is not discriminating — which is exactly the state
round 3 found by hand, on 39 tasks, that nobody had noticed.

Concretely: for any family of ≥N tasks, compute per-driver variance; WARN when
it falls below a threshold, naming the family and the collapsed pattern. This is
the automatic form of the finding that motivated the whole revamp, and **it must
ship before auto-apply**, not after. Auto-applying a scorer already proven flat
would industrialise the defect this loop exists to remove.

## 8. Build order

| # | slice | why here | depends on |
|---|---|---|---|
| **S1** | The ledger + cost rows | Data already exists; zero new instrumentation. Proves the join works | — |
| **S2** | **Degenerate-scorer alarm** | The control that replaces the human. **Ships before auto-apply** | S1 |
| **S3** | Auto-apply scores + auto-approve drivers | The T-3482 ruling, landed once a net exists | S2 |
| **S4** | Quality rows: rework, follow-on defects, operator corrections | All derivable from the corpus today | S1 |
| **S5** | Revisit mechanism on `revisit_at` + G-053 | Reuses an existing field and scan — **but see the write-half rule below: the field is set on 1 task of 1,196, so the reader must NOT come first** (OBS-540) | S1 |
| **S6** | Usage counters, paired with discoverability | Needs the pairing or it misreads unknown as unused. **Built (T-3499) — writer first, because the assumed feed counted hooks not verbs** | S1 |
| **S7** | Cross-agent adoption consults over the sidecar | Strongest signal, slowest to return | S5 |
| **S8** | Calibration: propose rubric vN+1 from deltas | Needs enough realised rows to be meaningful | S1, S4, S5 |

**S2 before S3 is the one ordering that is not negotiable.** Everything else can
move.

**The write-half rule (added T-3499, after S5 and S6 both hit it).** Before
building any slice's reader, measure whether its feed carries data. Twice now this
document named existing infrastructure and the infrastructure was not fed — S5's
`revisit_at` (1 of 1,196 tasks) and S6's verb counts (the wrong subject entirely).
In both cases the reader would have served an empty queue and looked finished.
**If the feed is unfed, the slice starts with the write half**, and the cost of
the slice is the cost of that write half — which is usually in shared, gated
infrastructure (`bin/fw` for S6, the close path for S5) and therefore much higher
than the doc's original ordering implied.

Consequence for S5, stated so it is not rediscovered a third time: S5 is **not**
"reuses an existing field and scan". It is "instrument the close path, then read".
Price it accordingly.

## 9. What this design does not solve

- **Per-task cost inside a parent session.** Named in §4.1, not closed. Needs
  turn-level attribution that does not exist.
- **Value for work no peer can adopt.** Internal governance changes have no
  cross-agent signal; they fall back to revisit-only, which is one operator
  judgement with no corroboration.
- **The cold start.** S8 cannot calibrate until enough realised rows exist. Until
  then the rubric is unchanged and the loop only *observes* — which is the
  honest state and should be reported as such rather than producing early
  adjustments from three datapoints.
