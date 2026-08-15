---
id: T-3022
name: "recall latency is O(corpus) — brute-force KNN scans 1.22GB per query"
description: >
  Inception: recall latency is O(corpus) — brute-force KNN scans 1.22GB per query

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: [tests/integration/test_recall_miss_live.py]
related_tasks: []
created: 2026-08-15T19:36:54Z
last_update: 2026-08-15T21:53:01Z
date_finished: 2026-08-15T21:53:01Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-08-15T19:39:19Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-08-15T19:45:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3022: recall latency is O(corpus) — brute-force KNN scans 1.22GB per query

## Problem Statement

A semantic recall costs ~1.0–1.2 s, and essentially all of it is a brute-force scan of
every vector in the corpus (1.22 GB per query). Cost is a function of corpus size and
nothing else, so latency grows linearly with a corpus that is designed to grow.

**The intercept is fine; the slope is the problem.** 1 s is tolerable interactively.
At 3× the corpus it is 3 s, and nothing in the system will report that as a fault —
each individual document added is legitimate, so there is no event to notice.

For whom: every agent that calls `fw recall` / `fw ask` / `/search`, and the RAG path.
Why now: the corpus went from effectively empty to 398,594 chunks this week (T-3016),
which is the first time the scan cost has been measurable at all — and hourly
incrementals mean it only goes one way from here.

Full measurements and candidate analysis: `docs/reports/T-3022-recall-latency-scaling.md`.

## Assumptions

- **A-1:** The corpus continues to grow. **Upgraded from weakly-held to supported by spike 6**
  — tracked content measured from git: 17.0 MB (2026-04-01) → 59.8 (06-01) → 108.9 (08-01) →
  147.3 MB (08-16). 8.7× in 4.5 months, and the last 15 days added 38.4 MB (≈2× the prior
  monthly rate). 76% of that recent growth is `.context/handovers`, which is what candidate E
  turns on. IW-7 depends on this and now has a measured slope rather than an assumption.
- **A-2:** Recall quality currently has thin headroom above the zero-clamp (known-good
  median 0.106, min 0.016), so any approximation that costs recall is riskier here than
  the general literature suggests. Measured, not assumed — see T-3021.
- **A-3:** Queries are global, not scoped. Holds for `fw recall` and `/search`; unverified
  for the RAG path, which is what IW-6 turns on.

## Open Questions

<!-- T-2190 (T-2186 Slice 4): every IW-N question must be disposed before
     --status work-completed. Disposition gate (agents/task-create/update-task.sh
     check_disposition_gate) refuses on under-disposed inceptions.

     Per-question shape:

       - **IW-1: <question text>**
         confidence: 0-3      (your confidence in your current answer; 0=guess, 3=verified)
         disposition: answered | deferred | dissolved
         rationale: <one-line evidence — file:line, decision id, dialogue ref>

     Never bare yes/no — the gate refuses bare checkboxes. See 050-Inceptions.md
     §Disposition Gate. Bypass: --skip-disposition-gate "rationale" (direct) or
     FW_SKIP_DISPOSITION_GATE=1 (env-var, T-1890 producer/consumer parity).
-->

- **IW-1: Is the ~1s recall latency a fixed brute-force scan, or does it scale with the result count?**
  confidence: 3
  disposition: answered
  rationale: measured on the live index — k=1 → 1028ms, k=200 → 1221ms. A 200× change in k moves latency 19%, so the cost is the scan, not result assembly. Full k-sweep table in `docs/reports/T-3022-recall-latency-scaling.md` §Measurements; commit `660fa0cf3`.

- **IW-2: Is the latency in the embedding call or the vector query?**
  confidence: 3
  disposition: answered
  rationale: vector query 1019ms of a 1000ms `_semantic_search`; novel-query embed 201ms (web/embeddings.py:228 `@lru_cache(maxsize=256)` hides it on repeats, so repeat queries are ~100% scan).

- **IW-3: Does sqlite-vec build an ANN index for `vec0`, or is the scan exhaustive by construction?**
  confidence: 3
  disposition: answered
  rationale: DDL at `web/embeddings.py:354` is `CREATE VIRTUAL TABLE vec_documents USING vec0(id INTEGER PRIMARY KEY, embedding FLOAT[768])` — no partition key, no ANN structure. 398,594 × 768 × 4B = 1.22 GB scanned per query. Confirmed empirically by spike 4, which built the bit-vector alternative alongside it: `docs/reports/T-3022-recall-latency-scaling.md` §Spike 4.

- **IW-4: Does binary quantization with full-vector rescoring preserve acceptable recall on THIS corpus?**
  confidence: 3
  disposition: answered
  rationale: built for real in sqlite-vec against all 398,594 vectors (spike 4). Answer is a qualified yes with a measured tradeoff curve, not the lossless win spike 2's simulation reported. Stage 1 is 1011ms → 64ms (15.8×); end-to-end 10.2× at N=100. Recall against exhaustive-KNN ground truth (10 queries) — N=50: top-1 100%, recall@3 87%, recall@10 80%. N=100: 100%/90%/87%. N=200: 100%/93%/92%. **Exact top-1 at every N; recall@10 plateaus near 95-96% and never reaches 100%.** This falsifies spike 2's 10.0/10 at N=50 — the ~540-vector pool had too few distractors, exactly as that spike's own Limits note warned. Design constraint discovered: rescore floats must live in a plain INTEGER PRIMARY KEY table (66ms) not the vec0 table (340ms via `id IN`, 118ms via per-id lookups) — `EXPLAIN QUERY PLAN` shows vec0 serves `id IN (…)` by full scan. Confidence 3 on the mechanism and the curve. The storage end-state was the last gap and spike 5 closed it: replacing `vec_documents` costs +28% (1.316GB → 1.682GB), duplicating +128%, and exhaustive exact KNN survives the replacement at 1743ms — so candidate D's drift audit stays implementable, which is what makes A safe to ship. Remaining unmeasured item is incremental bit-index maintenance, which is build work rather than a question. Full tables, method and the falsified spike-2 claim: `docs/reports/T-3022-recall-latency-scaling.md` §Spike 4 and §Spike 5.

- **IW-5: Does our embedding model support Matryoshka truncation (768→256), and at what recall cost?**
  confidence: 3
  disposition: answered
  rationale: model is `nomic-embed-text-v2-moe`; measured empirically rather than from docs — top-10 retention 8.8/10 at 512d (ρ=0.954), 8.2/10 at 256d (ρ=0.874), 6.0/10 at 128d. Graceful degradation but not strongly Matryoshka. Loses ~18% of top-10 for 3×, and has no rescore stage to recover it — dominated by IW-4's candidate on both axes. Full table plus the recorded method error (near-neighbour-only pool gave a spurious ρ=0.753): `docs/reports/T-3022-recall-latency-scaling.md` §Spike 1; commit `9c62305cd`.

- **IW-6: Is a partition key useful here, given recall is global rather than scoped?**
  confidence: 3
  disposition: dissolved
  rationale: `_rag_retrieve` (web/embeddings.py:1274-1277) selects `d.category` for output but never filters on it, and flattens BM25's per-category groups (`web/embeddings.py:1286`). No query path anywhere carries a scoping predicate, so a partition key would prune nothing. Candidate C is dead.

- **IW-7: What latency actually matters — is 1s a problem today, or only at projected growth?**
  confidence: 1
  disposition: deferred
  rationale: this is the go/no-go hinge and it is an operator judgment, not a measurement. 1s is tolerable interactively; the concern is the slope, not the intercept. Needs the growth rate over several incremental cycles, which only started accumulating this week.

## Exploration Plan

Three spikes. Done: the characterisation (IW-1/2/3) — measured, no further work needed.

- **Spike 1 — model capability check (IW-5), 15 min.** Resolve `EMBEDDING_MODEL` and
  determine whether it supports Matryoshka prefix truncation. Cheapest question here and
  it either opens candidate B or closes it outright.
- **Spike 2 — binary quantization recall measurement (IW-4), 2 h, time-boxed.** Build a
  bit-vector table over a corpus *sample*, run the same known-good / nonsense query set
  from T-3021, and measure how many known-good queries survive above the zero-clamp
  after two-stage rescoring. Sample, not full corpus — a full requantisation is build
  work and must not happen under an inception.
- **Spike 3 — RAG scopeability (IW-6), 30 min.** Read the RAG retrieval path to see
  whether it carries a category predicate that a partition key could prune on. Expected
  to dissolve the candidate; cheap enough to be worth confirming rather than assuming.

IW-7 is not a spike. It is the operator's call and needs a few weeks of growth data.

## Technical Constraints

- sqlite-vec `vec0` has **no ANN index** — there is no HNSW/IVF option to switch on. The
  scan is exhaustive by construction, so every candidate is about scanning *less data*
  rather than scanning *fewer rows*.
- Any change to vector storage format requires a **full reindex** — 95.9 min measured
  (T-3016), against a shared GPU host. That is the real cost floor on candidates A and B,
  and it means format experiments must run on a sample, not in place.
- The embedding host is shared infrastructure (`192.168.10.107:11434`); the local sidecar
  on 11435 is down (OBS-259). Measured at ~30 ms impact, so not a constraint on this work.
- Recall quality headroom is thin (A-2). An approximation that loses 10% recall in the
  literature may cost more here, because our scores sit close to the floor already.

## Scope Fence

**IN:** characterising the cost (done); measuring candidate approaches on a corpus
sample; producing a costed recommendation.

**OUT — explicitly:**
- Any change to the live vector store, index format, or embedding model. That is build
  work and requires GO first.
- Any full reindex. Sample-only during exploration.
- Tuning the T-3021 miss floor. Related (A-2) but a separate decision with its own
  evidence; bundling it here would make one go/no-go answer two questions.
- Fixing OBS-259. Measured as incidental to this problem.

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

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- The cost is characterised well enough to name what would change it — **met.** k-sweep,
  stage decomposition and the `vec0` DDL together show a fixed exhaustive scan.
- At least one candidate is evidence-backed rather than speculative — **met.** Binary
  quantization + exact rescore recovers the full exact top-10 at N=50, 32× less data.
- The build work is bounded and reversible — **met.** Two-stage retrieval sits behind a
  config flag with both paths live; no destructive migration, and the existing float
  vectors stay the source of truth for rescoring.

**NO-GO if:**
- The latency is acceptable at projected growth and the build cost is not worth it —
  **this is the live question**, and it is IW-7. I cannot settle it; it depends on how
  fast the corpus actually grows and how much 1 s (→ 2 s → 3 s) costs the operator.
- Every candidate requires an irreversible format migration — **not met.** A is additive.

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

**Rationale:**

The characterisation is complete and the leading candidate is now measured rather than
assumed. Recall costs ~1.0-1.2s and it is a fixed exhaustive scan: k=1 -> 1028ms,
k=200 -> 1221ms, so a 200x change in result count moves latency 19%. sqlite-vec `vec0`
has no ANN index by construction, so 1.22GB (398,594 x 768 x 4B) is compared per query.
Novel-query embedding adds 201ms; `@lru_cache` hides it on repeats, making repeat
recalls ~100% scan.

The important part is the shape, not the number. 1s is fine interactively. But the cost
depends only on corpus size, and the corpus is designed to grow -- hourly incrementals,
and one reindex this week took it from effectively empty to 398k chunks. There is no
moment at which this fails: every document added is legitimate, so nothing goes red, and
a latency budget would be met by raising the budget. That is why it is worth deciding
now rather than when someone notices.

Spikes ran in the same session and changed the candidate ranking. Binary quantization
with exact rescoring wins structurally rather than by tuning, because the final ranking is
computed from exact vectors, so the approximation only has to shortlist correctly, never
to order correctly. Dimension truncation (nomic-embed-text-v2-moe measured empirically:
8.2/10 top-10 at 256d) is dominated on both axes and drops to a fallback. Partition keys
are dissolved outright -- no query path in the system carries a scoping predicate.

**Spike 4 then built candidate A for real, at full corpus scale, and corrected two of my
own claims.** The speed holds: stage 1 is 1011ms -> 64ms (15.8x), end-to-end 10.2x at
N=100. The recall does not: N=50 gives 80% recall@10 on the real corpus, not the 100% the
540-vector simulation reported, and recall@10 plateaus near 95-96% at every N tested. The
simulation's own "required N grows with distractors" caveat turned out to be the finding.
What rescues it is that **exact top-1 survives at every N** -- the losses are entirely in
the tail. So candidate A is a ~10x speedup at exact top-1 and ~90% recall@3, not the
lossless win I described before.

Spike 4 also turned up a design constraint no simulation could have: the rescore floats
must live in a plain `INTEGER PRIMARY KEY` table. A vec0 virtual table does not serve
`id IN (...)` from an index -- `EXPLAIN QUERY PLAN` shows `SCAN ... VIRTUAL TABLE` -- so
the obvious implementation re-reads the 1.22GB it just avoided and yields 3x instead of
15x. Same algorithm, 5x apart, decided entirely by where the floats are stored.

**Spike 5 settled the last open item, and it is the one that makes the recommendation
coherent rather than merely fast.** Replacing `vec_documents` costs **+28% storage**
(1.316GB -> 1.682GB), not less -- vec0 packs vectors into contiguous chunks, a B-tree pays
per-row overhead. Duplicating would cost +128%. But the question that mattered was whether
an exact reference survives the replacement, because a drifting bit index would degrade
recall with no failure event -- the T-3021 shape exactly. It does: exhaustive exact KNN
over the plain table is 1743ms vs vec0's 1085ms, 1.6x slower and off the hot path.
**Candidate A is only safe to ship because candidate D remains implementable after it.**

What I am NOT claiming: that recall@10 can be made lossless (it cannot, at any N I
measured), that incremental bit-index maintenance is free (unbuilt, unmeasured, and the
one place A could reintroduce a silent-degradation surface), or that the current latency
is unacceptable. The GO is on the strength of the characterisation and the candidate, not
on urgency.

**If your standard is "the top result must not change", A meets it at every N tested. If
your standard is "the top-10 set must not change", A does not meet it at any N** -- and
candidate D (accept the latency, assert the shape) is then the honest answer instead. That
choice is yours and it is a different question from IW-7.

**Spike 6 found something that changes what I would do first, and I want it in front of you
before you rule.** Everything above optimises *how* the corpus is scanned; spike 6 asked what
is in it. **51% of the index (203,694 of 399,921 chunks) is `.context/handovers`** — 1,706
files, 89.6MB, and near-copies of each other by construction: 97% line overlap between
consecutive handovers, 93% between the latest and ten-back. They are also 76% of the last 15
days' growth, which is what makes the slope steep.

I expected that to be crowding out real results. It is not — 1 of 40 returned results across
4 real queries was a handover. Which makes the case stronger: **handovers cost 51% of every
scan and supply ~2.5% of the answers.**

So there is a **candidate E — stop indexing most handovers.** ~2× faster, exact recall
preserved on everything else, storage roughly halved, and it is subtraction rather than
construction: nothing to build, nothing to keep in lockstep, nothing that can silently
degrade. Smaller than candidate A's 10×, but far cheaper and trivially reversible, and the
two compose.

**My advice, revised by spike 6: try E first.** A remains the right answer if E is not
enough. What I am *not* claiming is that handovers should be excluded wholesale — they are
the session record and 2.5% is small but not zero, and my 4-query probe tested
framework-mechanism questions, not the "what was I doing last Tuesday" queries handovers
exist to answer. The retention design (recent N, unique sections only, or chunk-level dedup)
is a judgment call, and it is yours.

**Spike 8 reframes E, and I think this is the version you should actually rule on.** I went
looking for what the index holds too *little* of, and the inclusion set turns out to be wrong
in both directions. `web/search_utils.py:68` defines the corpus as seven directories plus
two globs. Invisible to `fw ask`, `fw recall` and the RAG path: **73 authored files totalling
0.54 MB** — every ADR, the architecture and design docs, the specs, the proposals, and all of
`policy/`, which includes `policy/standards/aef-bpmn-mapping-v1-partI.md` and
`policy/prompts/bvp-driver-session.md`. CLAUDE.md explicitly instructs agents to go and read both.

**One handover is 263 KB.** The entire authored-and-excluded set weighs about two handovers,
and we index 1,708 handovers and none of it. An agent asking `fw ask` how the BPMN seam works
gets handovers, not the standard that governs it.

So the sharper statement of E is not "stop indexing handovers":

> **The inclusion set is defined by directory and was never designed — it accreted. Define it
> by content class instead: authored-and-durable in, generated-or-restated out.**

Handovers are restated (97% overlap); ADRs are authored. One rule cuts both ways, and you make
one decision instead of two. It also explains the accretion without anyone being at fault —
each directory was added because someone wanted a specific thing findable, and nobody ever
asked what the set as a whole should be. The same rule keeps `docs/generated/` (1,068 files)
out, which is what stops the fix from repeating the original error.

**Advice, final form: rule on the inclusion set first (E′), then decide A on the remaining
corpus.** E′ is subtraction plus a small addition, trivially reversible, and needs no new
machinery. A is still the right answer if E′ is not enough.

**Two things I am not claiming.** That the 0.54 MB improves recall — it is 0.4% of the corpus
and will not move latency; the argument is reachability, not volume. And that handovers should
be excluded wholesale — 2.5% is small but not zero, my probe used framework-mechanism queries
rather than the "what was I doing last Tuesday" questions handovers exist to answer, and 832's
independent replication (arc 11936) reached the same limit from the other side: a tool census
shows no *tool* reads them, not that nobody does.

**The hinge is IW-7 and it is yours:** does 1s now, trending upward, cost enough to be
worth the build? That is a judgment about acceptable latency at projected growth, and no
measurement I can run settles it. Note that E′ is worth doing on reachability grounds even if
your answer to IW-7 is "no" — they are separable decisions and I have kept them separate.

**Spike 9 quantifies the "trending upward" half, and it strengthens E′ specifically.** Corpus
growth over the last month is **+62% (82.3 → 133.6 MB)**, and **79% of that growth is
`.context/handovers` alone** (+40.7 MB of +51.3 MB). Handovers are now **68% of the entire
indexed corpus**, and their share has risen **monotonically every month with no reversal**
(27 → 35 → 49 → 50 → 60 → 61 → 68%) because two factors compound: count 32 → 1,717 and
*average size* 4.5 KB → 54.2 KB. So E′ is no longer only a redundancy-and-reachability
argument — excluding handovers removes 68% of current volume and four fifths of the growth
rate, from the content spike 7 showed has **zero executable readers**. I have deliberately
*not* projected a future latency figure: that needs the vector-DB size to track source bytes
linearly and query cost to track index size linearly, neither of which is measured. The
defensible claim is the slope and its composition, not a date. **This does not decide IW-7
for you** — it replaces "trending upward" with a number so that you can.

**Spike 10 found the cause, and it adds a candidate F that I think is the real answer.** Spike
9 left the 12× per-handover size growth unexplained. Section accounting of a 265,888-byte
handover: **state dumps are 97.3%** of it — Observation Inbox 137,505 B, Work in Progress
69,568 B, Awaiting Your Action 48,355 B. The session narrative is ~2 KB, and the four sections
carrying the handover's actual purpose (decisions made, things tried that failed, open
questions, gotchas) total **175 bytes** — effectively empty. The dumps are not merely similar,
they are **byte-identical between consecutive handovers** (measured, 0 differing lines), and
99.7% / 100% identical across a three-hour gap with real work in between. At corpus scale these
sections are **82% of all 90.6 MB of handovers**. The cause is nameable: **the handover embeds
global state by value rather than by reference**, so bytes ≈ handovers × state-size with both
terms growing — which is the compounding spike 9 measured, and which explains spike 6's 97%
overlap exactly rather than by analogy. Nothing reported it because every individual handover
is correct; the defect is a property of the sequence, and nothing measures sequences.
**Candidate F** (fix the generator to reference rather than embed) removes ~74 MB and ~79% of
growth *at the source*, and makes handovers better to read rather than merely absent from the
index. **My sequencing advice: E′ first because it is free and needs no design agreement, F
next because it is the one that stops this recurring.** F is not free — it trades away offline
readability, and that tradeoff is yours, not mine. **I have not built either.**

**Checked archive-wide before standing behind it.** The byte-identical pairs are all from one
evening, which would leave "82% of the archive is dumps" true without implying the archive is
*redundant*. Sampled consecutive pairs at deciles across all 1,710 handovers: **8 of 9 are
≥96.3% identical** (100.0, 99.5, 97.1, 100.0, 100.0, 98.7, 96.3, 99.2), sustained March →
August. The single outlier is 47.2% and is a real event — that section halved, 681 → 327 lines
— which is the control the measurement needs to be worth anything. The same table shows the
state itself growing (135 → 1,014 lines), i.e. the second compounding term visible directly.
**Method error recorded:** my first similarity metric could return **negative** values (it
scored the outlier −11.3%), because `diff` emits both `<` and `>` lines on replacement; it
agreed with the correct metric to within a point on the eight well-behaved pairs and announced
itself only on the one that churned. Replaced with unchanged-lines over `max(len)`.

**Evidence:**

- **The cost is a fixed scan, not result assembly.** k-sweep on the live index: k=1 → 1028 ms, k=5 → 1048, k=50 → 1125, k=200 → 1221. A 200× change in k moves latency 19%.
- **Exhaustive by construction.** `CREATE VIRTUAL TABLE vec_documents USING vec0(id INTEGER PRIMARY KEY, embedding FLOAT[768])` — no partition key, no ANN index. 398,594 × 768 × 4 B = **1.22 GB compared per query**.
- **Stage decomposition.** vector query 1019 ms; novel-query embed 201 ms; cached embed 0 ms (`web/embeddings.py:228`, `@lru_cache(maxsize=256)`). Repeat recalls are ~100% scan.
- **Binary quantization + exact rescore, simulated (spike 2, ~540-vector pool).** N=10 → 6.5/10, N=25 → 9.5/10, N=50 → 10.0/10. First stage scans 96 B/vec vs 3072 B — 32× less. **Superseded at scale by spike 4 — see below.**
- **Spike 4: candidate A built in sqlite-vec against all 398,594 vectors.** Bit index = **48 MB** vs the float index's 1.58 GB; quantizing the corpus took 183 s. Stage 1: **1011 ms → 64 ms (15.8×)**, median over 5 queries.
- **Spike 4 recall curve (10 queries, ground truth = exhaustive float KNN).** N=50: top-1 100%, recall@3 87%, recall@10 80%, 66 ms (15.3×). N=100: 100% / 90% / 87%, 100 ms (10.2×). N=200: 100% / 93% / 92%, 177 ms (5.7×). N=400: 100% / 93% / 96%, 381 ms (2.7×). **Exact top-1 at every N; recall@10 never reaches 100%.**
- **Spike 4 falsified my own spike-2 headline.** "Identical to exhaustive search at N=50" was a 540-vector-pool artifact — the real corpus gives 8.0/10, not 10.0/10. Recorded as a correction rather than quietly restated, because the caveat I wrote at the time is what turned out to be true.
- **Spike 6: corpus growth quantified, and A-1 upgraded from weakly-held to supported.** Tracked `.md`/`.yaml`/`.txt` content: 17.0 MB (2026-04-01) → 59.8 (06-01) → 108.9 (08-01) → **147.3 MB (08-16)**. 8.7× in 4.5 months; the last 15 days added 38.4 MB, roughly double the prior monthly rate. *Method error recorded:* the first run walked `master`, 4 weeks stale (tip 2026-07-18, HEAD +1,432 commits), and showed growth flattening to zero — an artifact that was the exact opposite of the truth.
- **Spike 6: half the index is one document class.** `.context/handovers` = **203,694 of 399,921 chunks (51%)**; `.tasks/*` 124,652 (31%); `.context/episodic` 52,100 (13%); `docs/*` 15,481 (4%). Handovers are also 76% of growth since 2026-08-01. 1,706 files, 89.6 MB, median 40 KB, and near-duplicate by construction — **97% line overlap between consecutive handovers, 93% latest-vs-ten-back.**
- **Spike 6: a hypothesis of mine, disproved.** I expected 51% near-duplicate content to crowd real results out of the top-10. Measured on 4 real queries: **1 of 40 results was a handover.** No crowding. This strengthens rather than weakens candidate E — handovers cost 51% of the scan and supply ~2.5% of the answers.
- **Spike 5: storage end-state, measured per-table via `dbstat`.** Today `vec_documents` = 1.316 GB. After replacement: `floatvec` 1.637 GB + `bitvec` 0.045 GB = **1.682 GB (+28%)**. Duplicating instead = 3.0 GB (+128%). The plain table is *less* space-efficient than vec0 — the same chunked-layout fact that makes vec0 fast to scan and slow to point-look-up.
- **Spike 5: the exact reference survives the replacement.** Exhaustive exact KNN over the plain float table = **1743 ms** vs vec0's 1085 ms. 1.6× slower, off the hot path, and sufficient as ground truth for a periodic recall audit — so candidate D stays implementable after candidate A ships. Proposed end state: `bitvec` (45 MB) stage 1, `floatvec` (1.64 GB) stage 2 + exact reference, `vec_documents` dropped.
- **Spike 4 design constraint — where the floats live decides the win.** Rescore at N=50: `id IN (…)` against the vec0 float table = 340 ms; per-id point lookups = 118 ms; `id IN (…)` against a plain `INTEGER PRIMARY KEY` BLOB table = **66 ms**. `EXPLAIN QUERY PLAN` → `SCAN prod.vec_documents VIRTUAL TABLE INDEX 0:1`. The naive implementation re-reads the 1.22 GB it just avoided.
- **Dimension truncation measured, not assumed.** `nomic-embed-text-v2-moe`: 8.8/10 top-10 at 512d (ρ=0.954), 8.2/10 at 256d (ρ=0.874), 6.0/10 at 128d. 3× for ~18% of the top-10, with no rescore stage to recover it.
- **Partitioning dissolved.** `_rag_retrieve` selects `d.category` but never filters on it (`web/embeddings.py:1274`); BM25 per-category groups are flattened (`web/embeddings.py:1286`). Nothing to prune.
- **A hypothesis that failed, recorded.** The dead embed sidecar (OBS-259) costs ~30 ms, ≈3% — `ECONNREFUSED` returns immediately. Incidental field evidence that T-3017 failover works; downgrades OBS-259 to hygiene.
- **A measurement error, recorded.** The first truncation run used a near-neighbour-only pool and reported ρ=0.753 at 512d, non-monotonic against 256d. Near-tie ranks are unstable by construction; widening the pool moved it to 0.954. The first number looked like a finding and was an artifact of method.
- **Spike 7: independently replicated by 832-Workflow-designer, and it sharpens candidate E's question.** 832 measured the same shape on their tree (arc offset 11936): handovers = 55% of `.context/` (16M of 29M), 470 files, 87% median consecutive overlap, 88% whole-corpus redundancy. Two projects sharing a framework and not a codebase → this is a property of the framework's handover discipline, not of either tree. Running their "who reads these" measurement here, restricted to executable surfaces: **24 files reference `.context/handovers/LATEST.md`; exactly 1 names a historical `S-*` handover — `tests/integration/fw_timeline.bats:33`, which writes its own fixture.** Zero executable readers of real historical handovers; the other 53 refs are provenance citations in `.context/episodic/` (48) and `.tasks/completed/` (4). **The consequence is the opposite in form and the same in substance as 832's:** semantic retrieval is the *only* consumer historical handovers have. So the operator's question is not "does anything read these" but "is retrieval over 1,708 near-duplicate handovers worth half of every scan, for 2.5% of the answers?" Limit stated and unchanged: a grep cannot see ad-hoc human/agent reads, so the honest claim is "no *tool* reads them", not "nobody reads them" — and git preserves all 1,708 regardless, making this a working-set question, not a preservation one.
- **Spike 8: the inclusion set is wrong in both directions, which reframes candidate E.** `web/search_utils.py:68` defines the index by seven directories plus two globs. Invisible to `fw ask`/`recall`/RAG: **73 authored files, 0.54 MB** — `policy/` (19 files, incl. `policy/standards/aef-bpmn-mapping-v1-partI.md` and `policy/prompts/bvp-driver-session.md`, both of which CLAUDE.md explicitly directs agents to read), `docs/adr` (4), `docs/architecture`, `docs/design`, `docs/specs`, `docs/proposals`, `docs/articles` (25), `docs/upstream-patterns`, `docs/walkthrough`, `docs/dispatch-templates` — plus `.context/designer/` (42 `.bpmn` + registry, 988 KB). **One handover is 263 KB: the entire authored-excluded set weighs about two handovers, and we index 1,708 handovers and none of these.** Corrects OBS-252's fix direction — adding `.context/designer/` to `search_dirs` would index `registry.yaml` only, because the `aef:meta` prose lives inside `.bpmn` files (11 in `v1.bpmn`) and the suffix filter rejects them; the observation's remedy would have been a green change that fixed nothing. Also shows why a naive fix repeats the original error: `docs/generated/` is 1,068 generated files, so "index all of `docs/`" bulk-adds restated content exactly as handovers did. **Reframed E:** the inclusion set was never designed, it accreted by directory; define it by content class instead — authored-and-durable in, generated-or-restated out. Handovers are restated (97% overlap), ADRs are authored, and one rule cuts both ways, so the operator makes one decision rather than two. Not claimed: that 0.54 MB improves recall — it is 0.4% of the corpus and will not move latency. The argument is reachability, not volume.
- **Spike 9: "trending upward" is +62%/month and 79% of it is one directory.** Corpus bytes at monthly commits, filtered to the `web/search_utils.py:68` inclusion set: 0.5 → 6.4 → 20.7 → 35.5 → 73.8 → 82.3 → **133.6 MB** (Feb–Aug), the last month being the steepest on record at **+51.3 MB / +62%**. Decomposed before projecting, because one steep delta is not a trend: `.context/handovers` **+40.7 MB of the +51.3** (79%), `.tasks` +8.1, `.context/episodic` +1.5, `docs/reports` +0.7, all else +0.4. Not a bulk import — handovers accrete one per session, so the mechanism is structural. Six-month series shows it sustained and **compounding on two axes**: count 32 → 1,717 *and* average size 4.5 KB → **54.2 KB** (12×), so handover share of corpus rises **monotonically with no reversal** — 27 → 35 → 49 → 50 → 60 → 61 → **68%**. **Consequence for E′:** excluding handovers takes the indexed corpus 133.6 → 42.8 MB, removing 68% of volume and ~79% of growth, from content spike 7 showed has zero executable readers. **Method error recorded:** the first run used `master`, which is 122 commits stale (session runs on `t2539-staging`), and reported a *flat* tail (77.4 → 86.3 → 86.4 MB) that would have killed the case for any build. A measurement whose subject was "how fast does the corpus grow" silently answered "how fast does the branch I picked grow", and the wrong answer was plausible enough to act on. **Not claimed:** any projected future latency — that needs vector-DB size to track source bytes linearly and query cost to track index size linearly, neither measured here. The claim is the slope and its composition, not a date.
- **Spike 10: the redundancy has a named cause — the handover embeds state by value, not by reference.** Section accounting of `S-2026-0815-2318.md` (265,888 B): Observation Inbox 137,505 / Work in Progress 69,568 / Awaiting Your Action 48,355 / Gaps 1,617 / Deferred 1,584 = **97.3% state dumps**; the session narrative is ~2 KB, and `## Decisions Made This Session` (38 B) + `## Things Tried That Failed` (35 B) + `## Open Questions / Blockers` (36 B) + `## Gotchas` (66 B) = **175 bytes**, empty in a session that produced all four. Duplication measured directly, not inferred: consecutive handovers are **byte-identical** in Observation Inbox (137,876 B, 0 diff lines), Work in Progress (70,110 B) and Awaiting Your Action (48,686 B); across a **3-hour gap with real work between**, Work in Progress is 1,112 lines with 4 changed (**99.7%**) and Awaiting Your Action is **100%** identical. Corpus-scale: Work in Progress 43.6 MB + Awaiting Your Action 30.5 + Observation Inbox 6.8 + Gaps 1.6 = **82% of all 90.6 MB**. So bytes ≈ handovers × state-size with **both terms growing** — the compounding of spike 9, and the exact mechanism behind spike 6's 97% overlap. **Why invisible:** every individual handover is correct and its state real; the defect exists only as a property of the sequence, and nothing measures sequences. **New candidate F** — fix the generator to reference rather than embed: ~74 MB and ~79% of growth removed at source, and handovers become *better* to read (currently 342 B of "Where We Are" buried in 266 KB). **Not free:** it trades offline readability, which is a design call for the operator. Sequencing advice: **E′ first (free, no design agreement needed), F next (stops recurrence)**. Neither built.
- Artifact: `docs/reports/T-3022-recall-latency-scaling.md`. Commits: `660fa0cf3` (characterisation), `9c62305cd` (spikes 1-3).

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

### 2026-08-15 — run spike 4 before the operator decides, rather than after GO

- **Chose:** Build candidate A for real in sqlite-vec at full corpus scale while the
  inception is still open, instead of deferring it to build slice 1 as the artifact
  originally planned.
- **Why:** The GO's strength rested on a claim I had explicitly flagged as unmeasured
  ("32× is a data-volume argument"). If the bit-vector path had been slow, the
  recommendation would have been wrong, and the operator would have discovered that
  after approving it. A measurement that can change a recommendation belongs before the
  decision, not in the work the decision authorises. It is exploration, which is what an
  inception is for — no build artifact was written.
- **Rejected:** Waiting for GO. That would have shipped a recommendation resting on a
  simulation whose headline number (10.0/10 at N=50) spike 4 then falsified — the
  operator would have approved a lossless win and received a tradeoff curve.

### 2026-08-15 — report the narrowed claim rather than the stronger one

- **Chose:** Rewrite the recommendation around "~10× at exact top-1 and ~90% recall@3",
  and state plainly that recall@10 cannot be made lossless at any N measured.
- **Why:** Spike 4 improved the *speed* evidence (15.8× measured, not inferred) while
  degrading the *recall* evidence. Reporting only the improvement would have made the GO
  look stronger than it is. The operator's decision differs depending on whether their
  standard is "top result stable" or "top-10 set stable", so that fork is now surfaced
  explicitly instead of being absorbed into an average.
- **Rejected:** Restating spike 2's 10.0/10 alongside spike 4's 8.0/10 without saying
  which supersedes which. Two numbers for the same quantity, unranked, is how a
  falsified claim survives.

## Decision

**Decision**: GO

**Rationale**: The characterisation is complete and the leading candidate is now measured rather than
assumed. Recall costs ~1.0-1.2s and it is a fixed exhaustive scan: k=1 -> 1028ms,
k=200 -> 1221ms, so a 200x change in result count moves latency 19%. sqlite-vec `vec0`
has no ANN index by construction, so 1.22GB (398,594 x 768 x 4B) is compared per query.
Novel-query embedding adds 201ms; `@lru_cache` hides it on repeats, making repeat
recalls ~100% scan.

The important part is the shape, not the number. 1s is fine interactively. But the cost
depends only on corpus size, and the corpus is designed to grow -- hourly incrementals,
and one reindex this week took it from effectively empty to 398k chunks. There is no
moment at which this fails: every document added is legitimate, so nothing goes red, and
a latency budget would be met by raising the budget. That is why it is worth deciding
now rather than when someone notices.

Spikes ran in the same session and changed the candidate ranking. Binary quantization
with exact rescoring wins structurally rather than by tuning, because the final ranking is
computed from exact vectors, so the approximation only has to shortlist correctly, never
to order correctly. Dimension truncation (nomic-embed-text-v2-moe measured empirically:
8.2/10 top-10 at 256d) is dominated on both axes and drops to a fallback. Partition keys
are dissolved outright -- no query path in the system carries a scoping predicate.

**Date**: 2026-08-15T21:53:00Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-08-15T19:39:19Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1a8ec693
- **Timestamp:** 2026-08-15T21:53:02Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
## Recommendation Verdict (v1.0)

- **Scan ID:** RC-a938fc02
- **Timestamp:** 2026-08-15T21:53:02Z
- **Overall:** CONFIRMED
- **Claims:** 13

| Claim | Type | Status |
|-------|------|--------|
| `web/search_utils.py:68` | file_line | ✓ pass |
| `policy/standards/aef-bpmn-mapping-v1-partI.md` | file | ✓ pass |
| `policy/prompts/bvp-driver-session.md` | file | ✓ pass |
| `web/embeddings.py:228` | file_line | ✓ pass |
| `d.category` | module | ✓ pass |
| `web/embeddings.py:1274` | file_line | ✓ pass |
| `web/embeddings.py:1286` | file_line | ✓ pass |
| `.context/handovers/LATEST.md` | file | ✓ pass |
| `tests/integration/fw_timeline.bats:33` | file_line | ✓ pass |
| `v1.bpmn` | module | ✓ pass |
| `docs/reports/T-3022-recall-latency-scaling.md` | file | ✓ pass |
| `T-3021` | task | ✓ pass |
| `T-3017` | task | ✓ pass |
### 2026-08-15T21:53:00Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** The characterisation is complete and the leading candidate is now measured rather than
assumed. Recall costs ~1.0-1.2s and it is a fixed exhaustive scan: k=1 -> 1028ms,
k=200 -> 1221ms, so a 200x change in result count moves latency 19%. sqlite-vec `vec0`
has no ANN index by construction, so 1.22GB (398,594 x 768 x 4B) is compared per query.
Novel-query embedding adds 201ms; `@lru_cache` hides it on repeats, making repeat
recalls ~100% scan.

The important part is the shape, not the number. 1s is fine interactively. But the cost
depends only on corpus size, and the corpus is designed to grow -- hourly incrementals,
and one reindex this week took it from effectively empty to 398k chunks. There is no
moment at which this fails: every document added is legitimate, so nothing goes red, and
a latency budget would be met by raising the budget. That is why it is worth deciding
now rather than when someone notices.

Spikes ran in the same session and changed the candidate ranking. Binary quantization
with exact rescoring wins structurally rather than by tuning, because the final ranking is
computed from exact vectors, so the approximation only has to shortlist correctly, never
to order correctly. Dimension truncation (nomic-embed-text-v2-moe measured empirically:
8.2/10 top-10 at 256d) is dominated on both axes and drops to a fallback. Partition keys
are dissolved outright -- no query path in the system carries a scoping predicate.

### 2026-08-15T21:53:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
