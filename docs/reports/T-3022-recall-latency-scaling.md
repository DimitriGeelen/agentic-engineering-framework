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

## Candidates

Updated with spike results. C is dissolved; A now dominates B on both axes.

| # | Candidate | Measured effect | Status |
|---|-----------|-----------------|--------|
| **A** | **Binary quantization + exact rescore of top-N** | **32× less data scanned; 10.0/10 exact top-10 at N=50** | **Leading.** Recall proven on a sample; production N and real sqlite-vec bit-vector speed still unmeasured. |
| B | Matryoshka truncation 768→256 | 3×; 8.2/10 top-10 (ρ=0.874) | Dominated by A on both axes. Keep only as a fallback if A's bit-vector path proves unworkable in sqlite-vec. |
| C | Partition key | ~0 — no query path carries a scoping predicate | **Dissolved** (spike 3). |
| D | Accept, and assert the shape | 0 latency change | Still live, and not exclusive with A. |

A and D are not exclusive: the shape assertion is worth having regardless of which
optimisation lands, because it is what stops the next regression from being invisible.

## What is NOT claimed

- That 1 s is unacceptable. It is fine interactively today. The concern is the slope.
- That binary quantization is *fast* here. 32× less data is a volume argument; sqlite-vec's
  actual bit-vector scan throughput has not been measured, and constant factors could eat
  a good part of it.
- That N=50 is the production rescore depth. It is what sufficed on a 540-vector pool.
  Required N grows with distractor count and must be re-measured at full corpus scale.
- That the corpus will keep growing at the observed rate. One bulk reindex is not a
  growth curve. IW-7 depends on data that started accumulating this week.

## Open items

IW-1/2/3 answered at confidence 3, IW-5 at 3, IW-6 dissolved, IW-4 at confidence 2
(approach proven, parameters not). **IW-7 — "does this matter yet" — is the go/no-go
hinge and is the operator's, not mine.** It is a judgment about acceptable latency at
projected growth, and no measurement I can run will settle it.

The recommendation is GO on the basis that the characterisation is complete and the
leading candidate is now evidence-backed rather than speculative — not on the basis that
the latency is currently unacceptable, which I do not claim.

If GO, the build work splits cleanly:
1. Measure sqlite-vec bit-vector scan throughput at full corpus scale (settles the speed
   claim and the production N in one spike).
2. Two-stage retrieval behind a config flag, both paths available for A/B.
3. The shape assertion (candidate D) — independent of 1 and 2, and worth having either way.

## Dialogue Log

### 2026-08-15 — round 1, with 832-Workflow-designer (agent-chat-arc)

832 argued that value-based instruments are structurally blind to continuously-decaying
costs, and that shape assertions are the counter. Applied here without being asked to:
this investigation started as "is the dead embed sidecar costing us latency?" — a value
question — and the answer was no, 3%. Re-asking it as a shape question ("what does the
cost depend on?") produced the actual finding in one measurement.

Recorded because the reframing, not the measurement, is what found it. The measurement
was three lines of Python either way.
