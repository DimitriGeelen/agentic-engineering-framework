# T-3022 — Recall latency is O(corpus): brute-force KNN scans 1.22 GB per query

**Status:** inception, exploration in progress
**Filed:** 2026-08-15
**Recommendation:** GO (see `## Recommendation` in the task)

---

## Problem

A semantic recall against the framework index takes **~1.0–1.2 s**. Essentially all of
that is a brute-force scan of every vector in the corpus. The scan cost is a function
of corpus size and nothing else, so latency grows linearly with a corpus that is
designed to grow — hourly incrementals, ~9,150 documents today, 398,594 chunks.

The intercept is tolerable. **The slope is the finding.**

## Measurements

All figures from the live index on this host, 2026-08-15, after the T-3016 bulk
reindex (396,797 chunks at build time; 398,594 at measurement).

### The cost does not scale with result count

| k | median latency |
|---|----------------|
| 1 | 1028 ms |
| 5 | 1048 ms |
| 50 | 1125 ms |
| 200 | 1221 ms |

A **200× change in k moves latency 19%.** If the work were proportional to results
returned, k=200 would cost multiples of k=1. It does not. The dominant term is fixed
per query — a full scan — and only heap maintenance scales with k.

### Where the second goes

| stage | median |
|-------|--------|
| `_embed_single` (cached) | 0 ms |
| `_embed_single` (novel query, network) | 201 ms |
| vector query, k=15 | 1019 ms |
| `_semantic_search` end-to-end | 1000 ms |

`web/embeddings.py:228` wraps embedding in `@lru_cache(maxsize=256)`. Repeat queries
therefore skip the network entirely and are ~100% scan. A **novel** query pays
201 ms embed + ~1030 ms scan ≈ 1.23 s.

Worth stating because it inverts the intuitive diagnosis: the network call to the
embedding host is *not* the bottleneck, and the cache makes it look even smaller than
it is in real use.

### Why the scan is exhaustive

```sql
CREATE VIRTUAL TABLE vec_documents USING vec0(
    id INTEGER PRIMARY KEY,
    embedding FLOAT[768]
)
```

No partition key, no ANN structure — sqlite-vec `vec0` compares the query vector
against every stored vector. Data scanned per query:

```
398,594 vectors × 768 dims × 4 bytes = 1.22 GB
```

At ~1 s that is ≈1.2 GB/s, consistent with a memory-bandwidth-bound linear scan. The
number is not a symptom of a misconfiguration; it is what the chosen storage does.

### A hypothesis that was wrong, recorded because it was cheap to test

Every recall in this session logged `embed failover: http://127.0.0.1:11435 unusable
… retrying on http://192.168.10.107:11434` — the local sidecar (OBS-259) is down. I
expected a per-query tax from the failed connection attempt.

| configuration | median |
|---------------|--------|
| dead primary, failover to healthy host | 1052 ms |
| pointed directly at healthy host | 1022 ms |

**~30 ms, ≈3%.** `ECONNREFUSED` on localhost returns immediately rather than timing
out. The failover (T-3017) is genuinely cheap, and this is incidental field evidence
that it works. It downgrades OBS-259 from a performance issue to hygiene — worth
fixing, not worth prioritising as latency work.

## Why this class is easy to miss

The same shape as the `stat`-per-file pre-push gate diagnosed in T-3020, and as the
miss-signal defect in T-3021:

- No moment of failure. Nothing goes red. Latency degrades continuously, one document
  at a time, and every control we own is event-shaped.
- A **value** budget on query latency ("must be under 2 s") is either not yet breached
  or, once breached, is met by raising the number — the growth is legitimate.
- The **shape** assertion — "recall must not scan the entire corpus per query" — is
  true or false independent of corpus size, was false in May, is false now, and has
  no threshold to argue about.

Framing owed to 832-Workflow-designer, agent-chat-arc offset 11924: *values are
supposed to move, which is exactly why value-based instruments cannot see this class;
shapes are not supposed to move.*

## Spike results (2026-08-15, same session)

Three of the four deferred questions are now answered. Measured on real corpus vectors.

### Spike 1 — the model is `nomic-embed-text-v2-moe`, and truncation is mediocre

Tested empirically rather than taken from documentation: truncate the stored vectors to
d dims, re-rank, and compare against the full-dimension ordering.

| dims | top-10 retained | Spearman ρ | speedup |
|------|-----------------|-----------|---------|
| 512 | 8.8/10 | 0.954 | 1.5× |
| 384 | 7.8/10 | 0.922 | 2× |
| 256 | 8.2/10 | 0.874 | 3× |
| 128 | 6.0/10 | 0.772 | 6× |
| 64 | 5.4/10 | 0.674 | 12× |

Graceful degradation — the dimensions do carry decreasing information, so the model is
Matryoshka-*ish*. But a strongly Matryoshka-trained model holds ρ > 0.99 at 512d, and
this one loses ~12% of the top-10 there. **256d costs ~18% of the top-10 for 3×**, with
no second stage to recover it.

*Method note:* the first run of this measurement used a candidate pool of only the 60
nearest neighbours and reported ρ=0.753 at 512d, non-monotonic against 256d. That was an
artifact — ranks among near-ties are unstable by construction, so the tight pool measured
noise rather than truncation loss. Widening the pool to 40 near + 300 random moved ρ at
512d from 0.753 → 0.954. Recorded because the first number looked like a finding and was
a measurement error.

### Spike 2 — binary quantization + exact rescore is the strong candidate

Simulated the two-stage retrieval: rank the pool by Hamming distance over sign-bit
vectors (96 B/vec vs 3072 B — **32× less data**), take the top N, then rescore those N
with exact float cosine.

| rescore N | exact top-10 recovered |
|-----------|------------------------|
| 10 | 6.5/10 |
| 25 | 9.5/10 |
| **50** | **10.0/10** |
| 100 | 10.0/10 |
| 200 | 10.0/10 |

At N=50 the two-stage result is **identical to exhaustive search** on this sample, while
scanning 32× less data in the first stage.

This is the structural reason it beats truncation: the final ranking is computed from
*exact* vectors, so the approximation only has to be good enough to get the right
candidates into the shortlist — it never has to be good enough to order them. Truncation
has no such stage, so its error lands directly in the output.

**Limits, which matter more than the headline:**
- A Python simulation over a ~540-vector pool, not a live sqlite-vec bit-vector table.
  The *recall* result should transfer (it is arithmetic); the *speed* claim is inferred
  from data volume and has not been measured on sqlite-vec's bit-vector path.
- Required N almost certainly grows with corpus size — a 540-doc pool has far fewer
  distractors than 398,594. **N=50 is not a production parameter**, it is evidence that
  a modest N suffices in principle.
- 6 queries.

### Spike 3 — partitioning is dead (IW-6 dissolved)

`_rag_retrieve` selects `d.category` for display but never filters on it
(`web/embeddings.py:1274-1277`), and flattens BM25's per-category grouping (`:1286`).
No query path in the system carries a scoping predicate, so a partition key has nothing
to prune. Candidate C removed.

### Spike 4 — candidate A built for real, at full corpus scale (IW-4)

Spike 2 was a Python simulation over a ~540-vector pool. This is the same design built in
sqlite-vec against all 398,594 vectors on this host. It confirms the speed claim, **falsifies
the recall claim**, and turns up a design constraint the simulation could not have seen.

sqlite-vec v0.1.6 has `bit[N]` vec0 columns, `vec_quantize_binary()` and
`vec_distance_hamming()`. Quantizing the whole corpus took 183 s and produced a **48 MB**
index against the float index's 1.58 GB.

**Stage 1 is as fast as hoped:**

| | float L2, k=45 | bit Hamming, k=45 |
|---|---|---|
| median over 5 queries | 1011 ms | **64 ms** |

**15.8×.** 32× less data buys 16× less time — constant factors eat half, which is roughly
what a memory-bandwidth argument predicts and is the first direct evidence that the "32×"
figure in spike 2 was a data-volume claim rather than a latency one.

**Stage 2 is where the design is decided.** Rescoring the shortlist against exact floats
has to fetch N vectors by id, and *how* you fetch them dominates everything:

| rescore method | N=50 two-stage total |
|---|---|
| `WHERE id IN (…)` against the `vec0` float table | 340 ms |
| per-id point lookups against the `vec0` float table | 118 ms |
| `WHERE id IN (…)` against a plain `INTEGER PRIMARY KEY` BLOB table | **66 ms** |

`EXPLAIN QUERY PLAN` gives the reason: `SCAN prod.vec_documents VIRTUAL TABLE INDEX 0:1`.
A vec0 virtual table does not serve `id IN (…)` from an index — it scans, so the naive
two-stage re-reads the 1.22 GB it just avoided. Single-id lookup is optimised (2 ms), which
is why the loop form recovers most of it, and a plain B-tree table recovers the rest.

**This is the load-bearing finding of the spike.** The simulation could not surface it,
because in Python every candidate fetch is a dict lookup. Written the obvious way in SQL,
candidate A is a 3× win; written with the floats in a plain table, it is 15×. Same
algorithm, same recall, 5× apart — decided entirely by where the float vectors live.

**Recall, measured against exhaustive float KNN as ground truth (10 queries):**

| rescore N | top-1 exact | recall@3 | recall@10 | two-stage latency | speedup |
|---|---|---|---|---|---|
| 50 | **100%** | 87% | 80% | 66 ms | 15.3× |
| 100 | **100%** | 90% | 87% | 100 ms | 10.2× |
| 200 | **100%** | 93% | 92% | 177 ms | 5.7× |
| 400 | **100%** | 93% | 96% | 381 ms | 2.7× |
| 800 | — | — | 95% | 940 ms | 1.1× |

**Two corrections to spike 2, both against my own earlier claim:**

1. **"Identical to exhaustive search" is false at production scale.** Spike 2 reported
   10.0/10 at N=50; the real corpus gives **8.0/10**. Recall@10 never reaches 100% at any
   N I measured — it plateaus around 95-96%. The 540-vector pool had too few distractors,
   exactly the limitation flagged in spike 2's own "Limits" note. That caveat turned out to
   be the finding.
2. **N=50 is not a free lunch, and there is a real tradeoff curve.** Higher N buys recall
   and gives back speed roughly linearly. There is no knee — you pick a point on it.

**The result that makes candidate A viable anyway:** *top-1 is exact at every N tested,
including N=50.* The losses are entirely in the tail — ranks 4-10 reshuffle, the best match
never moves. For a retrieval path feeding RAG context this is the number that matters, and
it is the one place the approximation does not degrade at all.

**Honest reading:** candidate A is a **10× speedup at ~90% recall@3 and exact top-1**
(N=100), not the lossless 32× the simulation suggested. That is still a strong result and I
would still recommend it — but it is a tradeoff to be chosen, not a free win to be taken,
and the operator should see the curve rather than a headline.

**Not settled by this spike:**
- **Index maintenance.** The bit index must be rebuilt or incrementally updated in lockstep
  with the float index. A stale bit index degrades recall silently — precisely the T-3021
  failure shape — so candidate D's shape assertion becomes *more* necessary if A ships, not
  less.
- 10 queries, one host, warm page cache.

### Spike 5 — the storage end-state, and whether an exact reference survives

Spike 4 left "replace vs duplicate `vec_documents`" open. Per-table page accounting
(`dbstat`) settles it, and the result runs against the intuition that a plain table must be
the cheaper representation:

| | today | after replacement |
|---|---|---|
| `vec_documents` (vec0 chunks + rowids) | **1.316 GB** | — |
| `floatvec` (plain `INTEGER PRIMARY KEY` BLOB) | — | 1.637 GB |
| `bitvec` (vec0 bit chunks + rowids) | — | 0.045 GB |
| **total** | **1.316 GB** | **1.682 GB** |

**Replacing costs +28% storage, not less.** The raw vectors are 1.22 GB either way; vec0
packs them into contiguous chunk blobs, while a B-tree pays per-row overhead. That is the
same structural fact as the spike-4 rescore result seen from the other side: **vec0's
chunked layout is exactly what makes it fast to scan and slow to point-look-up, and the
plain table inverts both properties.** One layout, two consequences, and the design has to
pick which one it wants at each stage. Duplicating instead of replacing would cost
1.316 + 1.682 = **3.0 GB (+128%)**.

**The question that actually mattered was not storage.** If `vec_documents` is dropped,
is there still a way to compute exact exhaustive KNN — the ground truth any recall-drift
assertion has to compare against?

| exhaustive exact KNN, k=10 | |
|---|---|
| over `vec_documents` (vec0) | 1085 ms |
| over `floatvec` (plain table) | **1743 ms** |

Yes — 1.6× slower, and entirely acceptable because the exact path would no longer run per
query. It runs when something wants to *audit* the approximation.

This is the finding that makes the recommendation coherent rather than merely fast. The
risk I flagged in spike 4 was that shipping candidate A would introduce a silent-degradation
surface (a drifting bit index) of exactly the T-3021 shape. That risk is only manageable if
an exact reference remains computable, and spike 5 shows it does. **Candidate A and
candidate D are not just compatible — A is only safe to ship *because* D remains
implementable after it.**

Proposed end state, for the operator's information rather than as a decision I have made:
`bitvec` (45 MB) serves stage 1 per query; `floatvec` (1.64 GB) serves stage 2 rescore per
query and doubles as the exact reference for a periodic recall audit; `vec_documents` is
dropped. Net: **+28% storage, ~10× query latency, exact ground truth retained at 1.7 s
off the hot path.**

### Spike 6 — half the scan is one document class, and it is 2.5% of the answers

Everything above optimises *how* the corpus is scanned. This asks what is in it.

Corpus source growth, measured from git (`.md`/`.yaml`/`.txt`, tracked content):

| date | files | content |
|------|-------|---------|
| 2026-04-01 | 4,018 | 17.0 MB |
| 2026-06-01 | 8,878 | 59.8 MB |
| 2026-08-01 | 11,210 | 108.9 MB |
| 2026-08-16 | 12,700 | **147.3 MB** |

**A-1 is now strongly supported rather than weakly held:** 8.7× in 4.5 months, and the last
15 days added 38.4 MB — roughly double the prior monthly rate.

*Method note, recorded because it nearly shipped:* the first run of this measurement walked
`master`, which is 4 weeks stale (tip 2026-07-18; HEAD carries 1,432 commits it does not).
It showed growth flattening to zero after August 1 — an artifact of the branch, not a
property of the corpus, and the opposite of the truth. Same class as the spike-1 pool error.

**Where the growth is:**

| directory | added since 2026-08-01 | share |
|-----------|------------------------|-------|
| `.context/handovers` | 29.0 MB | **76%** |
| `.tasks/completed` | 4.3 MB | 11% |
| everything else | 5.1 MB | 13% |

**And where the index is:**

| source | chunks | share |
|--------|--------|-------|
| `.context/handovers` | **203,694** | **51%** |
| `.tasks/*` | 124,652 | 31% |
| `.context/episodic` | 52,100 | 13% |
| `docs/*` | 15,481 | 4% |

**Half the 1.22 GB scanned on every query is session handovers.** There are 1,706 of them,
median 40 KB, 89.6 MB total — and they are near-copies of each other by construction, since
each one restates current state: **97% line overlap between consecutive handovers, 93%
between the latest and ten-back.** Indexing all 1,706 is close to indexing one document
1,706 times.

**A hypothesis I had, and disproved.** If 51% of the index is near-duplicate, real documents
should be crowded out of results. Measured on 4 real queries: **1 of 40 returned results was
a handover.** The crowding effect is not there.

That makes the case *stronger*, not weaker. Handovers cost **51% of the scan** and supply
**~2.5% of the answers**. The most expensive half of the index is the half nobody retrieves.

**Candidate E: stop indexing (most) handovers.** Dropping them entirely takes the index from
399,921 to 196,227 chunks — **~2× faster, exact recall preserved on everything else, storage
roughly halved, no approximation and no drift surface.** Less headline speedup than
candidate A, but it is subtraction rather than construction: nothing to build, nothing to
keep in lockstep, nothing that can silently degrade.

**Not claimed:** that handovers should be deleted, or excluded wholesale. They are the
session memory record and must persist on disk regardless. The design question — index the
most recent N, index only each handover's unique sections, or deduplicate at chunk level —
is a retention judgment I have not made, and 2.5% is small but not zero. **Also not claimed:
that the 4-query probe settles retrieval value.** It shows handovers rarely surface for
framework-mechanism questions; it does not test the queries handovers exist to answer
("what was I doing last Tuesday"), and those may be exactly where they earn their place.

**A and E compose** — E halves the corpus, A gives ~10× on what remains. E is also the
cheaper thing to try first, and trying it costs almost nothing to reverse.

### Spike 7 — who actually reads a historical handover (independent replication, 832)

832-Workflow-designer replicated spike 6 on their own tree (arc offset 11936) and then ran
the measurement I had not thought to run. Their tree has no vector index, so "who retrieves
these" became "who *opens* these":

| | this tree | 832 |
|---|---|---|
| handover share | 51% of index chunks | 55% of `.context/` (16M of 29M) |
| files | 1,708 (94 MB) | 470 |
| consecutive line overlap | 97% | 87% median |
| latest vs ten-back | 93% | 83% |
| whole-corpus redundancy | — | 88% (99,937 lines → 11,815 distinct) |

Two projects sharing a framework and not a codebase, so the shape is a property of **the
framework's handover discipline**, not of either tree.

Running their measurement here, restricted to executable surfaces (`bin lib agents web
.claude tests`):

- **24** files reference `.context/handovers/LATEST.md`
- **1** file names a historical `S-*` handover — `tests/integration/fw_timeline.bats:33`,
  which `cat >`-writes its own fixture. It does not read a real one.

So: **zero executable readers of real historical handovers.** The other 53 references live in
`.context/episodic/` (48) and `.tasks/completed/` (4) — provenance citations recording which
handover a session produced, not reads.

**This does not say what it appears to say, and the difference is the finding.** On 832's tree
the conclusion is that historical handovers can leave the working set at zero mechanical cost.
Here the conclusion is the opposite in form and the same in substance: **semantic retrieval is
the only consumer they have.** Nothing else opens them. So the retention question is not "does
anything read these" — one thing does — it is precisely:

> Is semantic retrieval over 1,708 near-duplicate historical handovers worth half of every
> scan, given it returns them 2.5% of the time?

That is a sharper question than spike 6 could pose, and it is still the operator's. The limit
832 stated applies here unchanged and is the reason this is not a recommendation to exclude:
**a grep cannot see a human or an agent opening a handover ad hoc to ask what happened in
session X.** The honest claim is "no *tool* reads them", not "nobody reads them", and the
distance between those two sentences is the whole retention decision. Git preserves all 1,708
regardless of what the index holds, so this is a working-set question, not a preservation one.

### Spike 8 — the inclusion set is wrong in *both* directions, and that reframes E

Spikes 6 and 7 asked what the index holds too much of. This asks what it holds too little of,
because OBS-252 (filed during T-3010, unactioned) claimed the designer corpus is not indexed at
all. Verified still true, and the verification corrected the observation's own fix direction.

`web/search_utils.py:68` — the complete inclusion set, seven directories plus two globs:

```
.tasks/            .context/episodic/    .context/project/     .context/handovers/
.fabric/components/  .context/qa/        docs/reports/
+ PROJECT_ROOT/*.md   + agents/*/AGENT.md
```

Filtered to `.md`, `.yaml`, `.yml`.

**What that leaves invisible to `fw ask` / `fw recall` / RAG:**

| Excluded | Files | Size |
|---|---|---|
| `policy/` — incl. `policy/standards/aef-bpmn-mapping-v1-partI.md`, `policy/prompts/bvp-driver-session.md`, `value-drivers.yaml`, `anti-patterns.yaml` | 19 | 187 KB |
| `docs/articles` | 25 | 156 KB |
| `docs/architecture`, `docs/design`, `docs/specs`, `docs/adr`, `docs/proposals` | 13 | 128 KB |
| `docs/upstream-patterns`, `docs/walkthrough`, `docs/dispatch-templates` | 16 | 83 KB |
| **total authored-and-excluded** | **73** | **0.54 MB** |
| `.context/designer/` — 42 `.bpmn` + `registry.yaml` | 43 | 988 KB |

**The number that makes the case: one handover is 263 KB.** The entire authored-and-excluded
set — every ADR, the architecture and design docs, the BPMN mapping standard, the whole BVP
prompt bundle — weighs about **two handovers**. We index 1,708 of those and none of these.

Two of the excluded files are ones CLAUDE.md explicitly instructs agents to go and read:
`policy/prompts/bvp-driver-session.md` ("**Always start here.** Keystone") and
`policy/standards/aef-bpmn-mapping-v1-partI.md` — the mapping standard governing the very seam
T-3018 exists to protect. An agent that asks `fw ask` how the BPMN seam works gets handovers.

**OBS-252's fix direction is insufficient, and this is why verifying before filing matters.**
It proposed adding `.context/designer/` to `search_dirs`. That would index `registry.yaml` and
nothing else: the `aef:meta` prose lives *inside* the `.bpmn` files (11 occurrences in `v1.bpmn`
alone), and the suffix filter rejects `.bpmn`. The observation's diagnosis was right and its
remedy would have produced a green change that fixed nothing — the same shape as everything
else in this artifact.

**Why a naive fix repeats the handover mistake.** `docs/` also contains `docs/generated/`
(1,068 files), which is generated and belongs out. "Index all of `docs/`" would bulk-add
restated content — precisely the error that made handovers 51% of the corpus.

**This reframes candidate E rather than adding to it.** E was "stop indexing most handovers."
The better statement of the same decision is:

> **The inclusion set is defined by directory and was never designed — it accreted. It should
> be defined by content class: authored-and-durable in, generated-or-restated out.**

Under that rule handovers are *restated* (97% consecutive overlap) and ADRs are *authored*, so
one rule cuts both ways and the operator makes one decision instead of two. It also explains
the accretion without blaming anyone: every directory in that list was added because someone
wanted a specific thing findable, and nobody ever asked what the set as a whole should be.

**Not claimed:** that indexing 0.54 MB measurably improves recall. It is 0.4% of the corpus and
will not move latency at all. The argument is not volume, it is that the content agents are
directed to read should be reachable by the tool built to find things — and `fw corpus explain`
existing for designer maps is not a substitute, because it only helps an agent who already
knows the map exists.

### Spike 9 — "trending upward" is +62%/month, and 79% of it is one directory

IW-7 asks whether 1s, trending upward, costs enough to justify the build. "Trending upward"
was the vague half, and it is recoverable from git history without building anything:
`git ls-tree -r -l` at monthly commits, filtered to the inclusion set from
`web/search_utils.py:68` and the `.md/.yaml/.yml` suffix filter.

**First result was wrong, and the way it was wrong is worth recording.** Run against `master`
the series flattens: 77.4 → 86.3 → 86.4 MB over the last three months, which reads as a corpus
that has stopped growing and would have killed the case for any build. `master` is 122 commits
stale — the session runs on `t2539-staging`. The flat tail was the branch, not the corpus.
A measurement whose subject is "how fast does this grow" silently answered "how fast does the
branch I happened to pick grow", and the answer was plausible enough to act on.

Re-run against the live branch:

| Date | Files | Corpus MB |
|------|-------|-----------|
| 2026-02-15 | 191 | 0.5 |
| 2026-03-15 | 1,617 | 6.4 |
| 2026-04-15 | 3,754 | 20.7 |
| 2026-05-15 | 5,554 | 35.5 |
| 2026-06-15 | 7,267 | 73.8 |
| 2026-07-15 | 7,679 | 82.3 |
| 2026-08-15 | 9,139 | **133.6** |

The last month is the steepest on record: **+51.3 MB, +62%.**

**Reconciliation with spike 6 / A-1, which quotes 147.3 MB.** Both are right and they measure
different things. At HEAD: all tracked files = 190.3 MB; all tracked `.md/.yaml/.yml` = 148.3 MB
(spike 6's quantity, "tracked content"); the **indexed subset** — the seven `search_dirs` plus
two globs — = 133.6 MB. The 14.7 MB gap is `.md/.yaml` outside the inclusion set, overwhelmingly
`docs/generated/` (1,068 generated files), which is consistent with spike 8: of that gap only
**0.54 MB is authored** content that arguably belongs in the index. Where the two spikes overlap
they agree — spike 6 put handovers at 76% of recent growth, spike 9 at 79% over a different
window.

**A single steep month is not a trend**, and extrapolating from one delta is the error class
this artifact has already been caught by twice. So the month was decomposed by directory before
any projection:

| Directory | Jul → Aug | Delta |
|-----------|-----------|-------|
| `.context/handovers` | 50.1 → 90.8 MB | **+40.7** |
| `.tasks` | 18.7 → 26.8 MB | +8.1 |
| `.context/episodic` | 6.9 → 8.4 MB | +1.5 |
| `docs/reports` | 5.4 → 6.1 MB | +0.7 |
| everything else | — | +0.4 |

**79% of the growth is handovers alone.** Not a bulk import — handovers accrete one per
session, so the mechanism is structural and continues by construction.

The six-month series confirms it is sustained, and shows it is **two compounding factors**:

| Date | Handover MB | Share of corpus | Count | Avg size |
|------|-------------|-----------------|-------|----------|
| 2026-02-15 | 0.1 | 27% | 32 | 4.5 KB |
| 2026-03-15 | 2.2 | 35% | 341 | 6.6 KB |
| 2026-04-15 | 10.1 | 49% | 593 | 17.5 KB |
| 2026-05-15 | 17.7 | 50% | 871 | 20.8 KB |
| 2026-06-15 | 44.2 | 60% | 1,312 | 34.5 KB |
| 2026-07-15 | 50.1 | 61% | 1,379 | 37.2 KB |
| 2026-08-15 | **90.8** | **68%** | 1,717 | **54.2 KB** |

Count grew 54×; **average handover size grew 12×**, 4.5 KB → 54.2 KB. Bytes are count × size
and both are climbing, which is why the share of corpus rises **monotonically, every month,
with no reversal**: 27 → 35 → 49 → 50 → 60 → 61 → 68%.

**What this does to the recommendation.** E′ was argued on redundancy (97% overlap, spike 6)
and on reachability (spike 8). Neither was a performance argument. This is: handovers are
**68% of current corpus volume and 79% of its growth rate**, they are the most redundant
content in the index, and spike 7 established they have **zero executable readers** — semantic
retrieval is their only consumer. Excluding them takes the indexed corpus from 133.6 MB to
42.8 MB and removes four fifths of the growth.

**What this does to IW-7.** The question was "is 1s worth the build?" The better-posed question
is that the corpus is on a monotonic trajectory to spend an ever-larger majority of every scan
on its least informative content. 1s is not the cost; the slope is. **Deliberately not
projected to a specific future latency** — that would require assuming the vector-DB size
tracks source bytes linearly and that query cost tracks index size linearly, and neither is
measured here. The defensible claim is the slope and its composition, not a date.

### Spike 10 — the redundancy has a named cause, and it is a generator defect

Spike 9 left one thing unexplained: mean handover size grew 12× (4.5 KB → 54.2 KB). "The
handover agent writes fatter files" is a restatement, not a cause. Section-level accounting
of a representative recent handover (`S-2026-0815-2318.md`, 265,888 bytes):

| Section | Bytes | |
|---------|-------|--|
| `## Observation Inbox` | 137,505 | state dump |
| `## Work in Progress` | 69,568 | state dump |
| `## Awaiting Your Action (Human)` | 48,355 | state dump |
| `## Gaps Register` | 1,617 | state dump |
| `## Deferred With No Revisit Date` | 1,584 | state dump |
| `## Recent Commits` | 472 | session |
| `## Files Changed This Session` | 367 | session |
| `## Where We Are` | **342** | session |
| `## Suggested First Action` | 129 | session |
| `## Gotchas / Warnings for Next Session` | 66 | session |
| `## Decisions Made This Session` | **38** | session |
| `## Open Questions / Blockers` | **36** | session |
| `## Things Tried That Failed` | **35** | session |

**State dumps are 97.3% of the file.** The session narrative — everything that describes what
actually happened — is about 2 KB, and the four sections carrying the handover's stated purpose
(decisions, failures, open questions, gotchas) total **175 bytes**, i.e. they are effectively
empty templates.

**Are the dumps redundant between handovers?** Measured directly, not inferred:

- Consecutive handovers (`…2318` vs `…2321`): `## Observation Inbox` **byte-identical**,
  137,876 bytes, 0 differing lines. `## Work in Progress` byte-identical, 70,110 bytes.
  `## Awaiting Your Action` byte-identical, 48,686 bytes.
- Across a **3-hour gap with real work in between** (`…2201` vs `…2321`): Work in Progress
  1,112 lines with **4 changed (99.7% identical)**; Awaiting Your Action **100% identical**.

At corpus scale across all 1,710 handovers (90.6 MB): Work in Progress 43.6 MB, Awaiting Your
Action 30.5 MB, Observation Inbox 6.8 MB, Gaps 1.6 MB — **82% of all handover bytes are these
dumps.**

**Is the duplication archive-wide, or only recent?** The pairs above are all from one evening,
which would make "82% of the archive is dumps" true without implying the archive is redundant.
Sampled consecutive pairs at deciles across all 1,710 handovers, `## Work in Progress`:

| Pair | lines A | lines B | identical |
|------|---------|---------|-----------|
| 2026-03-16 | 135 | 135 | 100.0% |
| 2026-04-06 | 419 | 419 | 99.5% |
| 2026-04-26 | 681 | 327 | **47.2%** |
| 2026-05-15 | 344 | 352 | 97.1% |
| 2026-05-28 | 406 | 406 | 100.0% |
| 2026-06-09 | 479 | 479 | 100.0% |
| 2026-07-06 | 702 | 694 | 98.7% |
| 2026-08-03 | 903 | 933 | 96.3% |
| 2026-08-08 | 1,014 | 1,007 | 99.2% |

**8 of 9 are ≥96.3%, sustained from March to August** — the duplication is a property of the
archive, not of tonight. The 47.2% outlier is a genuine event, not noise: that section *halved*
(681 → 327 lines), which is what a real task cleanup looks like. Its presence is the useful
part — it shows the metric can detect change, which is the control the measurement needs to be
worth anything.

Note also the left column: 135 → 419 → 406 → 479 → 702 → 1,014 lines. **The state being copied
is itself growing**, which is the second term in the compounding and is visible directly here.

**Method note.** The first version of this measurement scored similarity as
`100 − 100 × difflines / seclines` and returned **−11.3%** for the outlier pair, because a
`diff` emits both `<` and `>` lines when content is *replaced*, so the count can exceed the
section length. A similarity metric that can go negative is not a similarity metric. Replaced
with unchanged-line count over `max(len_a, len_b)`. Recorded because the bad metric would have
inflated every duplication figure in this section, and it announced itself only on the single
pair that happened to churn — on the eight well-behaved pairs it agreed with the correct metric
to within a point, which is exactly how a broken instrument earns trust. (The Observation Inbox is small historically and huge now: the backlog reached 150
pending items only recently, which is why it dominates the *current* file but not the archive.)

**The cause.** The handover embeds current state **by value rather than by reference**. Each
handover is a full snapshot of slow-moving global state — active tasks, pending human actions,
the observation backlog — so total bytes ≈ *number of handovers × size of state*, and **both
terms grow independently**. That is the compounding spike 9 measured, and it explains spike 6's
97% consecutive-overlap figure exactly rather than by analogy: consecutive handovers are 97%
identical because 97% of each one is the same snapshot.

**Why nothing reported it.** Every individual handover is correct. The state it embeds is real,
current, and was legitimately worth writing down once. There is no defective handover to find,
and no event to notice — the defect is only visible as a property of the *sequence*, which
nothing measures.

**This is a better lever than E′, and it is a different kind of fix.** E′ removes handovers
from the index — treating the symptom, and losing the 2 KB of real narrative along with the
258 KB of duplication. Fixing the generator to reference rather than embed would cut ~74 MB
(82%) from the handover corpus and ~79% from total corpus growth, while making handovers
*better* to read: a human opening a 266 KB file to learn what happened this session is
currently reading 342 bytes of answer buried in a quarter-megabyte of unchanged state.

**Not claimed:** that this is trivial to implement, or that the referenced state should
disappear from the handover entirely — a handover that a reader can consume without a live
system has value, and "reference not embed" trades that away. That tradeoff is a design
question, and it is the operator's. What is measured here is only the cost of the current
choice and the fact that it was never a choice — the sections accreted one at a time, exactly
as the inclusion set did in spike 8.

**Secondary finding, filed not chased:** `## Decisions Made This Session` (38 B),
`## Things Tried That Failed` (35 B) and `## Open Questions / Blockers` (36 B) are empty in a
session that made decisions, had failures, and left open questions — several of them recorded
in this very artifact. The handover's own quality-decay concern (G-018) is about exactly this,
and the sections that would carry the antifragile content are the ones going unfilled while
the mechanical dumps grow without bound.

## Candidates

Updated after spike 4, which built candidate A for real. C is dissolved; A still leads B,
but on a measured tradeoff curve rather than the lossless win spike 2 suggested.

| # | Candidate | Measured effect | Status |
|---|-----------|-----------------|--------|
| **A** | **Binary quantization + exact rescore of top-N** | **Built at full scale (spike 4): 10.2× at N=100 — exact top-1, 90% recall@3, 87% recall@10. Stage 1 alone is 15.8×.** | **Leading, and now measured rather than simulated.** Requires floats in a plain PK table, not the vec0 table — otherwise 3× instead of 15×. |
| B | Matryoshka truncation 768→256 | 3×; 8.2/10 top-10 (ρ=0.874) | Dominated by A on both axes. Keep only as a fallback if A's bit-vector path proves unworkable in sqlite-vec. |
| C | Partition key | ~0 — no query path carries a scoping predicate | **Dissolved** (spike 3). |
| D | Accept, and assert the shape | 0 latency change | Live, and now shown to be A's **precondition** rather than its alternative (spike 5). |
| **E** | **Stop indexing (most) handovers** | **~2× — 51% of the index (203,694 chunks) is handovers, supplying ~2.5% of results. Exact recall preserved; storage halved.** | **New (spike 6). Try first.** Subtraction, not construction: nothing to build, keep in lockstep, or silently degrade. Composes with A. |

| **F** | **Fix the handover generator: reference state instead of embedding it** | **~74 MB of 90.6 MB handover corpus (82%), and ~79% of total corpus growth. Measured: consecutive handovers byte-identical across all three dump sections; 99.7%/100% identical across a 3-hour gap.** | **New (spike 10). Addresses the cause that E′ treats as a symptom.** Not subtraction — this is a generator change with a real design tradeoff (offline readability), so it is not free the way E is. |

A and D are not exclusive: the shape assertion is worth having regardless of which
optimisation lands, because it is what stops the next regression from being invisible.

**E′ and F are the same problem at two removes, and the order matters.** F removes the
duplication at the source, which shrinks the index, git, and every human read of a handover.
E′ removes handovers from the index, which shrinks only the index — but it works today, costs
nothing to build, and does not depend on agreeing a design for what a handover should contain.
They compose: doing F does not make E′ wrong, because even a deduplicated handover corpus is
still 1,710 session narratives with 97% consecutive overlap in the parts that remain. The
honest sequencing advice is **E′ first because it is free, F next because it is right**, and
F is the one that stops this recurring.

## What is NOT claimed

- That 1 s is unacceptable. It is fine interactively today. The concern is the slope.
- ~~That binary quantization is *fast* here.~~ **Settled by spike 4: 15.8× on stage 1,
  10.2× end-to-end at N=100, measured on the full corpus.**
- ~~That N=50 is the production rescore depth.~~ **Settled by spike 4, against my own
  earlier claim: N=50 gives 80% recall@10 at full scale, not the 100% the 540-vector
  simulation reported. There is a tradeoff curve and a point must be chosen on it.**
- That recall@10 can be made lossless. It cannot, at any N I measured — it plateaus near
  95-96%. Exact top-1 survives; the tail does not.
- ~~That the storage end-state is settled.~~ **Settled by spike 5: replacing costs
  +28% (1.316 GB → 1.682 GB), duplicating costs +128%, and the exact reference survives
  the replacement at 1743 ms.**
- That the bit index can be kept in lockstep for free. Incremental maintenance is
  unbuilt and unmeasured, and it is the one place candidate A could reintroduce a
  silent-degradation surface.
- That the corpus will keep growing at the observed rate. One bulk reindex is not a
  growth curve. IW-7 depends on data that started accumulating this week.

## Open items

IW-1/2/3 answered at confidence 3, IW-5 at 3, IW-6 dissolved, **IW-4 raised to confidence 3
by spike 4** — the approach is built, the speedup measured, and the recall curve mapped on
the real corpus. **IW-7 — "does this matter yet" — is the go/no-go hinge and is the
operator's, not mine.** It is a judgment about acceptable latency at projected growth, and
no measurement I can run will settle it.

The recommendation remains GO, and spike 4 strengthens the evidence while *narrowing the
claim*: the win is ~10× at exact top-1 and ~90% recall@3, not the lossless 32× spike 2
implied. If the operator's standard is "the top result must not change", A meets it at
every N tested. If the standard is "the top-10 set must not change", A does not meet it at
any N, and candidate D (accept and assert the shape) is the honest answer instead.

If GO, the build work splits cleanly:
1. ~~Measure sqlite-vec bit-vector scan throughput at full corpus scale.~~ **Done — spike 4.**
   ~~Remaining sub-question: the storage end-state.~~ **Done — spike 5.** Nothing left to
   measure before building; what remains is incremental bit-index maintenance, which is
   build work rather than a question.
2. Two-stage retrieval behind a config flag, both paths available for A/B. **Design
   constraint from spike 4: the rescore floats must live in a plain `INTEGER PRIMARY KEY`
   table. Reading them from the vec0 table costs 5× and silently converts the win into a
   rounding error.**
3. The shape assertion (candidate D) — independent of 1 and 2, and worth having either way.
   **Spike 4 raises its priority: a bit index that drifts out of lockstep with the float
   index degrades recall with no failure event, which is the T-3021 shape exactly.**

## Dialogue Log

### 2026-08-15 — round 1, with 832-Workflow-designer (agent-chat-arc)

832 argued that value-based instruments are structurally blind to continuously-decaying
costs, and that shape assertions are the counter. Applied here without being asked to:
this investigation started as "is the dead embed sidecar costing us latency?" — a value
question — and the answer was no, 3%. Re-asking it as a shape question ("what does the
cost depend on?") produced the actual finding in one measurement.

Recorded because the reframing, not the measurement, is what found it. The measurement
was three lines of Python either way.

### 2026-08-15 — round 2, no interlocutor: spike 4 against my own claim

No dialogue partner here; recorded because the reasoning changed direction and the trail
is the point.

The artifact listed "measure sqlite-vec bit-vector throughput at full corpus scale" as
build step 1 — work the operator's GO would authorise. Running it *before* the decision
inverted that, on the ground that a measurement capable of changing a recommendation
belongs before the decision it would change. Had the bit-vector path been slow, the GO
would have been wrong and the operator would have found out only after approving it.

It did not come out the way I expected in either direction. The speed claim I was least
sure of held (15.8×, better than the memory-bandwidth argument suggested for a 32× data
reduction). The recall claim I had been confident enough to headline — 10.0/10 at N=50,
"identical to exhaustive search" — was wrong at scale by two full documents, and the
reason was written in my own "Limits" note at the time: too few distractors in a
540-vector pool.

The pattern is worth naming, because it is the third instance this session and the same
one 832 and I have been circling. T-3021: a rule verified against a sparse index, true
when written, silently false once the corpus filled. T-3023: tests that construct their
own input through their own assumptions. Spike 2: a simulation whose stated limitation
was the finding. In all three the flaw was **recorded at the time and read as a caveat
rather than as a prediction.** A limitation you write down and do not test is not a
hedge — it is an untested hypothesis wearing a hedge's clothes.

Also worth recording: the largest single effect in spike 4 was not the algorithm at all.
Whether the rescore floats sit in a vec0 table or a plain B-tree table moves the
end-to-end result 5× — more than the difference between candidates A and B. A simulation
in Python cannot see that, because there every fetch is a dict lookup. The thing that
decided the design was the storage layer the simulation had abstracted away.
